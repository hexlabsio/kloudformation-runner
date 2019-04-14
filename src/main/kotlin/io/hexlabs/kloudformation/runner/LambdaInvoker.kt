package io.hexlabs.kloudformation.runner

import software.amazon.awssdk.core.SdkBytes
import software.amazon.awssdk.regions.Region
import software.amazon.awssdk.services.lambda.LambdaClient
import software.amazon.awssdk.services.lambda.model.InvokeRequest
import java.io.File
import java.util.Base64

class LambdaInvoker(val region: Region, val client: LambdaClient = LambdaClient.builder().region(region).build()) {

    private fun encoded(value: String) = Base64.getEncoder().encode(textFrom(value).toByteArray())
    private fun textFrom(value: String) = if (value.startsWith("file://")) File(value.substringAfter("file://")).readText() else value

    fun invokeLambda(functionName: String, invocationType: String, logType: String, payload: String? = null, qualifier: String? = null, context: String? = null) {
        try {
            val response = client.invoke(InvokeRequest.builder()
                .functionName(functionName)
                .invocationType(invocationType)
                .logType(logType)
                .apply {
                    payload?.let { payload(SdkBytes.fromByteArray(textFrom(it).toByteArray())) }
                    qualifier?.let { qualifier(it) }
                    context?.let { clientContext(String(encoded(it))) }
                }
                .build()
            )
            response.logResult()?.let {
                if (logType != "None") {
                    println()
                    println("Logs (max up to 4Kb)")
                    println(String(Base64.getDecoder().decode(it)))
                }
            }
            if (response.statusCode() in 200..299) {
                if (logType != "None") {
                    val payload = String(response.payload().asByteArray())
                    if (payload != "null") {
                        println()
                        println("Response: $payload")
                    }
                }
            } else {
                System.err.println("Error with status code ${response.statusCode()}")
                System.err.println(response.functionError() ?: "")
                System.err.println(String(response.payload().asByteArray()))
                System.exit(response.statusCode())
            }
        } catch (exception: Exception) {
            System.err.println(exception.message)
        }
    }
}