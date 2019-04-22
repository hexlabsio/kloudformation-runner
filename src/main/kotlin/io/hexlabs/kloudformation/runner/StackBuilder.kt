package io.hexlabs.kloudformation.runner

import software.amazon.awssdk.regions.Region
import software.amazon.awssdk.services.cloudformation.CloudFormationClient
import software.amazon.awssdk.services.cloudformation.model.Capability
import software.amazon.awssdk.services.cloudformation.model.CloudFormationException
import software.amazon.awssdk.services.cloudformation.model.CreateStackRequest
import software.amazon.awssdk.services.cloudformation.model.DeleteStackRequest
import software.amazon.awssdk.services.cloudformation.model.DescribeStackResourcesRequest
import software.amazon.awssdk.services.cloudformation.model.DescribeStacksRequest
import software.amazon.awssdk.services.cloudformation.model.Stack
import software.amazon.awssdk.services.cloudformation.model.StackResource
import software.amazon.awssdk.services.cloudformation.model.StackStatus
import software.amazon.awssdk.services.cloudformation.model.UpdateStackRequest

class StackBuilder(val region: String, val client: CloudFormationClient = CloudFormationClient.builder().region(Region.of(region)).build()) {

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
        client.updateStack(UpdateStackRequest.builder().capabilities(Capability.CAPABILITY_NAMED_IAM).stackName(stack).templateBody(template).build())
        println()
        println("Updating Stack $stack")
        println()
    }
    private fun create(stack: String, template: String) {
        client.createStack(CreateStackRequest.builder().capabilities(Capability.CAPABILITY_NAMED_IAM).stackName(stack).templateBody(template).build())
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
            } else {
                System.err.println(error.message)
                System.exit(1)
            }
        } else {
            System.err.println(error.message)
            System.exit(1)
        }
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

    fun createOrUpdate(stackName: String, template: String): OutputInfo? {
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
                result.stack?.outputs().orEmpty().forEach {
                    println("${it.outputKey()}: ${it.outputValue()}")
                }
                println()
                return OutputInfo(result.stack?.outputs().orEmpty().map { it.outputKey() to it.outputValue() }.toMap())
            } else {
                System.err.println()
                System.err.println("Stack Update Failure")
                System.err.println()
                System.exit(1)
            }
        } catch (error: CloudFormationException) { handle(error) }
        return null
    }

    data class Result(val stack: Stack?, val success: Boolean)

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
                Result(stack, successStatuses.contains(status))
            } else {
                Thread.sleep(5000)
                waitFor(stackName, successStatuses, status.toString(), reason, resources)
            }
        } ?: Result(null, success = successStatuses.contains(StackStatus.DELETE_COMPLETE))
    }
}
