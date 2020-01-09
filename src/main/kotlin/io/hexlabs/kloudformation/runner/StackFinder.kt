package io.hexlabs.kloudformation.runner

import software.amazon.awssdk.regions.Region
import software.amazon.awssdk.services.cloudformation.CloudFormationClient
import software.amazon.awssdk.services.cloudformation.model.Stack
import software.amazon.awssdk.services.cloudformation.model.StackStatus

fun matching(name: String): (Stack) -> Boolean {
    return {
        it.stackId() == name || it.stackName() == name || Regex(".*$name.*").matches(it.stackId())
    }
}

val availableStackStatuses = listOf(StackStatus.CREATE_COMPLETE, StackStatus.UPDATE_COMPLETE, StackStatus.UPDATE_ROLLBACK_COMPLETE)

class StackFinder(val region: String, val client: CloudFormationClient = CloudFormationClient.builder().region(Region.of(region)).build()) {
    fun listOutputsFor(name: String) =
        client.describeStacks().stacks()
        .filter { availableStackStatuses.contains(it.stackStatus()) }
        .filter(matching(name))
        .sortedBy { it.stackName() }
        .firstOrNull()?.let {
            it.outputs().joinToString("\n") { "${it.outputKey()}=${it.outputValue()}" }
        } ?: ""
}
