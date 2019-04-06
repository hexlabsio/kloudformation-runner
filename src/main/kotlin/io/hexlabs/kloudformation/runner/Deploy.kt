package io.hexlabs.kloudformation.runner

import software.amazon.awssdk.regions.Region
import software.amazon.awssdk.services.cloudformation.CloudFormationClient
import software.amazon.awssdk.services.cloudformation.model.CloudFormationException
import software.amazon.awssdk.services.cloudformation.model.CreateStackRequest
import software.amazon.awssdk.services.cloudformation.model.DescribeStackResourcesRequest
import software.amazon.awssdk.services.cloudformation.model.DescribeStacksRequest
import software.amazon.awssdk.services.cloudformation.model.Stack
import software.amazon.awssdk.services.cloudformation.model.StackResource
import software.amazon.awssdk.services.cloudformation.model.StackStatus
import software.amazon.awssdk.services.cloudformation.model.UpdateStackRequest
import software.amazon.awssdk.services.cloudformation.model.DeleteStackRequest
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

class StackBuilder(val region: Region, val client: CloudFormationClient = CloudFormationClient.builder().region(region).build()) {

    private fun stackExistsWith(name: String): Boolean = stackWith(name) != null
    fun stackWith(name: String): Stack? = try {
        client.describeStacks(DescribeStacksRequest.builder().stackName(name).build()).stacks().firstOrNull()
    } catch (error: CloudFormationException) {
        if (error.awsErrorDetails().errorMessage() == "Stack with id $name does not exist") null
        else throw error
    }

    private val terminalStatuses = listOf(
        StackStatus.CREATE_COMPLETE,
        StackStatus.CREATE_FAILED,
        StackStatus.DELETE_COMPLETE,
        StackStatus.DELETE_FAILED,
        StackStatus.ROLLBACK_COMPLETE,
        StackStatus.ROLLBACK_FAILED,
        StackStatus.UPDATE_COMPLETE,
        StackStatus.UPDATE_ROLLBACK_COMPLETE,
        StackStatus.UPDATE_ROLLBACK_FAILED
    )
    private val successStatuses = listOf(
        StackStatus.CREATE_COMPLETE,
        StackStatus.UPDATE_COMPLETE
    )
    private val deleteSuccessStatuses = listOf(
        StackStatus.DELETE_COMPLETE
    )
    private fun update(stack: String, template: String) {
        client.updateStack(UpdateStackRequest.builder().stackName(stack).templateBody(template).build())
        println()
        println("Updating Stack $stack")
        println()
    }
    private fun create(stack: String, template: String) {
        client.createStack(CreateStackRequest.builder().stackName(stack).templateBody(template).build())
        println()
        println("Creating Stack $stack")
        println()
    }
    private fun delete(stack: String) {
        client.deleteStack(DeleteStackRequest.builder().stackName(stack).build())
        println()
        println("Deleting Stack $stack")
        println()
    }
    private fun handle(error: CloudFormationException) {
        val errorDetails = error.awsErrorDetails()
        val errorCode = errorDetails.errorCode()
        if (errorCode == "ValidationError") {
            if (errorDetails.errorMessage() == "No updates are to be performed.") {
                println()
                println("Update Complete (No Change)")
                println()
            } else System.err.println(error.message)
        } else System.err.println(error.message)
    }
    fun listStacks() {
        println()
        println("Stacks in the $region region")
        println()
        client.describeStacksPaginator().stacks().stream().map { it.stackName() to it.stackStatusAsString() }.forEach {
                (stack, status) -> println("$stack $status")
        }
        println()
    }
    fun deleteStack(name: String) {
        println()
        println("#################### Stack Delete #######################")
        println()
        try {
            delete(name)
            val result = waitFor(name, deleteSuccessStatuses)
            if (result.success) {
                println()
                println("Stack Delete Complete")
                println()
            } else {
                System.err.println()
                System.err.println("Stack Delete Failure")
                System.err.println()
                System.exit(1)
            }
        } catch (error: CloudFormationException) {
            handle(error)
        }
    }

    fun createOrUpdate(stackName: String, template: String) {
        println()
        println("#################### Stack Deploy #######################")
        println()
        try {
            if (stackExistsWith(stackName)) update(stackName, template)
            else create(stackName, template)
            val result = waitFor(stackName, successStatuses)
            if (result.success) {
                println()
                println("Stack Update Complete")
                println()
            } else {
                System.err.println()
                System.err.println("Stack Update Failure")
                System.err.println()
                System.exit(1)
            }
        } catch (error: CloudFormationException) { handle(error) }
    }

    data class Result(val success: Boolean)

    private fun print(logicalId: String, type: String, status: String, physicalId: String?, reason: String?) = println("$logicalId $type Status became $status" + (reason?.let { " because $it" } ?: "") + (physicalId?.let { " ($it)" } ?: ""))

    private fun printResourceUpdates(previousResources: List<StackResource>, currentResources: List<StackResource>) {
        fun print(resource: StackResource) = print(resource.logicalResourceId(), resource.resourceType() ?: "", resource.resourceStatusAsString(), resource.physicalResourceId(), resource.resourceStatusReason())
        currentResources.forEach { resource ->
            val oldVersion = previousResources.find { it.logicalResourceId() == resource.logicalResourceId() }
            if (oldVersion != null) {
                if (oldVersion.resourceStatus() != resource.resourceStatus() || (oldVersion.resourceStatusReason() != resource.resourceStatusReason() && resource.resourceStatusReason() != null))
                    print(resource)
            } else print(resource)
        }
        previousResources.filter { resource -> currentResources.find { it.logicalResourceId() == resource.logicalResourceId() } == null }
            .forEach { println(it.logicalResourceId() + " has been removed") }
    }

    private fun waitFor(stackName: String, successStatuses: List<StackStatus>, previousStackStatus: String? = null, previousStackReason: String? = null, previousResources: List<StackResource> = emptyList()): Result {
        return stackWith(stackName)?.let { stack ->
            val status = stack.stackStatus()
            val reason = stack.stackStatusReason()
            val resources = client.describeStackResources(DescribeStackResourcesRequest.builder().stackName(stackName).build()).stackResources()
            if (previousResources.isNotEmpty()) {
                printResourceUpdates(previousResources, resources)
            }
            if (status.toString() != previousStackStatus || reason != previousStackReason)
                print(stack.stackName(), "AWS::CloudFormation::Stack", status.toString(), stack.stackId(), reason)
            if (terminalStatuses.contains(status)) {
                Result(successStatuses.contains(status))
            } else {
                Thread.sleep(5000)
                waitFor(stackName, successStatuses, status.toString(), reason, resources)
            }
        } ?: Result(success = successStatuses.contains(StackStatus.DELETE_COMPLETE))
    }
}
