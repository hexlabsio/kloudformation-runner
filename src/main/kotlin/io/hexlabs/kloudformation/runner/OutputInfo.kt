package io.hexlabs.kloudformation.runner

data class OutputInfo(val outputs: Map<String, String> = emptyMap()) {
    operator fun plus(output: Pair<String, String>) = copy(outputs = outputs + output)
}