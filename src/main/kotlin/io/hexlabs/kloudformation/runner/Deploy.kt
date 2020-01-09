package io.hexlabs.kloudformation.runner

import java.io.File
import java.lang.IllegalArgumentException
import java.time.Clock
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.UUID

sealed class Option(open val name: String) {
    data class MonoOption(override val name: String) : Option(name)
    data class BinaryOption(override val name: String, val value: String) : Option(name)
    data class WaitingOption(override val name: String) : Option(name)
    fun equals(name: String) = this.name == name
}
operator fun <T : Option> List<T>.get(message: String, compare: T.() -> Boolean) = find {
    compare(it)
} ?: throw IllegalArgumentException(message)
operator fun <T : Option> List<T>.get(name: String) = this["Expected $name argument", { equals(name) } ]
fun <T : Option> List<T>.has(name: String) = notRequired(name) != null
fun <T : Option> List<T>.notRequired(name: String, compare: T.() -> Boolean = { equals(name) }) = find { compare(it) }

data class Options(val options: List<Option> = emptyList()) {
    val binaryOptions = options.filter { it is Option.BinaryOption }.map { it as Option.BinaryOption }
    val monoOptions = options.filter { it is Option.MonoOption }.map { it as Option.MonoOption }
    companion object {
        fun isBinary(arg: String) = arg.startsWith("-") && !arg.startsWith("--")
        fun from(args: List<String>): Options {
            return if (args.isEmpty()) Options()
            else {
                val initial = args.first().let { if (isBinary(it)) Option.WaitingOption(it) else Option.MonoOption(it) }
                val initialOptions = if (initial is Option.WaitingOption) emptyList() else listOf(initial)
                val options = args.drop(1).fold(initial to initialOptions) { (previous, options), arg ->
                    when {
                        previous is Option.WaitingOption -> Option.BinaryOption(previous.name, arg).let { it to (options + it) }
                        isBinary(arg) -> Option.WaitingOption(arg) to options
                        else -> Option.MonoOption(arg).let { it to (options + it) }
                    }
                }
                Options(if (options.second.isEmpty()) options.second + Option.MonoOption(args.last()) else options.second)
            }
        }
    }
}

fun generateKey(location: String): String {
    val current = LocalDateTime.now(Clock.systemUTC())
    val formatter = DateTimeFormatter.ofPattern("yyyy-MM-dd-HH:mm:ss.SSS")
    val formatted = current.format(formatter)
    val file = File(location)
    return UUID.randomUUID().toString() + "-" + formatted + "/" + if (file.isFile) file.name else file.name + ".zip"
}

fun main(args: Array<String>) {
    val options = Options.from(args.toList())
    val command = options.monoOptions.firstOrNull()?.name ?: "deploy"
    val region = options.binaryOptions["-region"].value
    val outputFile = options.binaryOptions.notRequired("-output")?.let { File(it.value).also { it.parentFile?.mkdirs() } }
    val stackBuilder = StackBuilder(region)
    when (command) {
        "list" -> stackBuilder.listStacks()
        "uploadZip" -> {
            val bucket = options.binaryOptions["-bucket"].value
            val directory = options.binaryOptions["-location"].value
            val key = options.binaryOptions.notRequired("-key")?.value ?: generateKey(directory.substringAfterLast("/"))
            val s3Syncer = S3Syncer(region)
            s3Syncer.uploadCodeDirectory(directory, bucket, key)
        }
        "invoke" -> {
            val namePattern = Regex("(arn:(aws[a-zA-Z-]*)?:lambda:)?([a-z]{2}(-gov)?-[a-z]+-\\d{1}:)?(\\d{12}:)?(function:)?([a-zA-Z0-9-_\\.]+)(:(\\\$LATEST|[a-zA-Z0-9-_]+))?")
            val functionName = options.binaryOptions["-function-name must match ${namePattern.pattern}", { name == "-function-name" && value.matches(namePattern) } ].value
            val invocationType = options.binaryOptions.notRequired("-type")?.value ?: "RequestResponse"
            val logType = if (options.monoOptions.has("--disable-logs")) "None" else "Tail"
            val qualifierPatter = Regex("(|[a-zA-Z0-9\\$\\_-]+)")
            val qualifier = options.binaryOptions.notRequired("-qualifier must match ${qualifierPatter.pattern}") { name == "-qualifier" && value.matches(qualifierPatter) }?.value
            val clientContext = options.binaryOptions.notRequired("-context")?.value
            val payload = options.binaryOptions.notRequired("-payload")?.value
            LambdaInvoker(region).invokeLambda(functionName, invocationType, logType, payload, qualifier, clientContext)
        }
        "outputs" -> {
            options.binaryOptions.notRequired("-stacks")?.value?.split(",")
                ?.forEach { stack ->
                        val stackRegion = if (stack.contains(':')) stack.substringBefore(':') else region
                        println(StackFinder(stackRegion).listOutputsFor(stack.substringAfter(':')))
                    }
        }
        "deploy" -> {
            val stackName = options.binaryOptions["-stack-name"].value
            val templateFile = File(options.binaryOptions["-template"].value)
            if (!templateFile.exists()) throw IllegalArgumentException("Could not find file $templateFile")
            else {
                stackBuilder.createOrUpdate(stackName, templateFile.readText())?.let {
                    outputFile?.writeText(it.outputs.toList().joinToString(separator = "\n") { (key, value) -> "$key=$value" })
                }
            }
        }
        "delete" -> {
            val stackNames = options.binaryOptions["Expected -stack-name or -stack-names argument", { name.startsWith("-stack-name") } ].value
            val force = options.monoOptions.has("--force")
            stackNames.split(",").forEach { stackName ->
                if (stackBuilder.stackWith(stackName) != null) {
                    if (!force) {
                        System.out.println("Are you sure you want to delete the stack named $stackName in the $region region? (y/n)")
                        val answer = readLine()
                        if (answer == "y") {
                            System.out.println("You may also use the --force argument to ignore prompt")
                            stackBuilder.deleteStack(stackName)
                        }
                    } else stackBuilder.deleteStack(stackName)
                } else {
                    println()
                    println("Stack $stackName in region $region does not exist")
                    println()
                }
            }
        }
        else -> System.err.println("Command $command not recognised try deploy or delete")
    }
    outputFile?.let {
    }
}