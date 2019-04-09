package io.hexlabs.kloudformation.runner

import software.amazon.awssdk.core.sync.RequestBody
import software.amazon.awssdk.regions.Region
import software.amazon.awssdk.services.s3.S3Client
import software.amazon.awssdk.services.s3.model.PutObjectRequest
import software.amazon.awssdk.services.s3.model.ServerSideEncryption
import java.io.BufferedInputStream
import java.io.ByteArrayOutputStream
import java.util.zip.ZipEntry
import java.io.File
import java.io.FileInputStream
import java.lang.IllegalArgumentException
import java.util.zip.ZipOutputStream

class S3Syncer(val region: Region, val client: S3Client = S3Client.builder().region(region).build()) {
    fun uploadCodeDirectory(directory: String, bucket: String, key: String) {
        val zipBytes = zipAll(directory)
        client.putObject(PutObjectRequest.builder().serverSideEncryption(ServerSideEncryption.AES256).bucket(bucket).key(key).build(), RequestBody.fromBytes(zipBytes))
    }
}

fun zipAll(directory: String): ByteArray {
    val sourceFile = File(directory)
    if(sourceFile.exists()) {
        return if (sourceFile.isFile) sourceFile.readBytes()
        else ByteArrayOutputStream().use { ZipOutputStream(it).use { zipFiles(it, sourceFile, "") }; it.toByteArray() }
    } else throw IllegalArgumentException("Could not find file or directory at $directory")
}

private fun zipFiles(zipOut: ZipOutputStream, sourceFile: File, parentDirPath: String) {
    val data = ByteArray(2048)
    for (f in sourceFile.listFiles()) {
        if (f.isDirectory) {
            val path = if (parentDirPath == "") {
                f.name
            } else {
                parentDirPath + File.separator + f.name
            }
            val entry = ZipEntry(path + File.separator)
            entry.time = f.lastModified()
            entry.isDirectory
            entry.size = f.length()
            zipOut.putNextEntry(entry)
            zipFiles(zipOut, f, path)
        } else {
            if (!f.name.contains(".zip")) {
                FileInputStream(f).use { fi ->
                    BufferedInputStream(fi).use { origin ->
                        val path = parentDirPath + File.separator + f.name
                        val entry = ZipEntry(path)
                        entry.time = f.lastModified()
                        entry.isDirectory
                        entry.size = f.length()
                        zipOut.putNextEntry(entry)
                        while (true) {
                            val readBytes = origin.read(data)
                            if (readBytes == -1) {
                                break
                            }
                            zipOut.write(data, 0, readBytes)
                        }
                    }
                }
            } else {
                zipOut.closeEntry()
                zipOut.close()
            }
        }
    }
}