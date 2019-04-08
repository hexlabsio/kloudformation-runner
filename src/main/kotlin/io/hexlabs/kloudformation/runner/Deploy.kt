package io.hexlabs.kloudformation.runner

import software.amazon.awssdk.regions.Region
import java.io.File
import java.lang.IllegalArgumentException

sealed class Option {
    data class MonoOption(val name: String) : Option()
    data class BinaryOption(val name: String, val value: String) : Option()
    data class WaitingOption(val name: String) : Option()
}
data class Options(val options: List<Option> = emptyList()) {
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

fun main(args: Array<String>) {
    val allOptions = Options.from(args.toList()).options
    val options = allOptions.filter { it is Option.BinaryOption }.map { it as Option.BinaryOption }
    val commands = allOptions.filter { it is Option.MonoOption }.map { it as Option.MonoOption }
    val command = commands.firstOrNull()?.name ?: "deploy"
    val region = options.find { it.name == "-region" }?.value ?: throw IllegalArgumentException("Expected -region argument")
    val stackBuilder = StackBuilder(Region.of(region))
    when (command) {
        "list" -> stackBuilder.listStacks()
        "uploadZip" -> {
            val bucket = options.find { it.name == "-bucket" }?.value ?: throw IllegalArgumentException("Expected -bucket argument")
            val key = options.find { it.name == "-key" }?.value ?: throw IllegalArgumentException("Expected -key argument")
            val directory = options.find { it.name == "-location" }?.value ?: throw IllegalArgumentException("Expected -location argument")
            val s3Syncer = S3Syncer(Region.of(region))
            s3Syncer.uploadCodeDirectory(File(directory), bucket, key)
        }
        "deploy" -> {
            val stackName = options.find { it.name == "-stack-name" }?.value ?: throw IllegalArgumentException("Expected -stack-name argument")
            val templateFile = File(
                options.find { it.name == "-template" }?.value
                    ?: throw IllegalArgumentException("Expected -template argument")
            )
            if (!templateFile.exists()) throw IllegalArgumentException("Could not find file $templateFile")
            else stackBuilder.createOrUpdate(stackName, templateFile.readText())
        }
        "delete" -> {
            val stackNames = options.find { it.name.startsWith("-stack-name") }?.value ?: throw IllegalArgumentException("Expected -stack-name or -stack-names argument")
            val force = commands.find { it.name == "--force" }
            stackNames.split(",").forEach { stackName ->
                if (stackBuilder.stackWith(stackName) != null) {
                    if (force == null) {
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
}