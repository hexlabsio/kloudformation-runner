package io.hexlabs.kloudformation.runner

import software.amazon.awssdk.core.sync.RequestBody
import software.amazon.awssdk.regions.Region
import software.amazon.awssdk.services.s3.S3Client
import software.amazon.awssdk.services.s3.model.PutObjectRequest
import software.amazon.awssdk.services.s3.model.ServerSideEncryption
import java.io.ByteArrayOutputStream
import java.util.zip.ZipEntry
import java.io.File
import java.util.zip.ZipOutputStream

class S3Syncer(val region: Region, val client: S3Client = S3Client.builder().region(region).build()) {
    fun uploadCodeDirectory(directory: File, bucket: String, key: String) {
        val zipBytes = ByteArrayOutputStream().use { byteStream ->
            ZipOutputStream(byteStream).use { zipStream -> zip(directory, directory.nameWithoutExtension, zipStream) }
            byteStream.toByteArray()
        }
        client.putObject(PutObjectRequest.builder().serverSideEncryption(ServerSideEncryption.AES256).bucket(bucket).key(key).build(), RequestBody.fromBytes(zipBytes))
    }

    private fun zip(directory: File, fileName: String, zipOut: ZipOutputStream) {
        if (directory.isDirectory) {
            if (fileName.endsWith("/")) {
                zipOut.putNextEntry(ZipEntry(fileName))
                zipOut.closeEntry()
            } else {
                zipOut.putNextEntry(ZipEntry("$fileName/"))
                zipOut.closeEntry()
            }
            val children = directory.listFiles()
            for (childFile in children!!) {
                zip(childFile, fileName + "/" + childFile.name, zipOut)
            }
        } else {
            val zipEntry = ZipEntry(fileName)
            zipOut.putNextEntry(zipEntry)
            zipOut.write(directory.readBytes())
        }
    }
}