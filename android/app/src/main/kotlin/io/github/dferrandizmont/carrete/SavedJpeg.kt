package io.github.dferrandizmont.carrete

import java.io.EOFException
import java.io.File
import java.io.FileNotFoundException
import java.io.RandomAccessFile
import java.nio.file.Files
import java.nio.file.NoSuchFileException
import java.nio.file.attribute.BasicFileAttributes

/** A completed legacy export. Real I/O failures propagate so recovery can wait. */
internal fun isSavedJpeg(file: File): Boolean = try {
    val attributes = Files.readAttributes(file.toPath(), BasicFileAttributes::class.java)
    if (!attributes.isRegularFile || attributes.size() < 4) false
    else RandomAccessFile(file, "r").use {
        if (it.readUnsignedShort() != 0xffd8) false
        else {
            it.seek(it.length() - 2)
            it.readUnsignedShort() == 0xffd9
        }
    }
} catch (_: NoSuchFileException) {
    false
} catch (error: FileNotFoundException) {
    // RandomAccessFile also uses this exception for permission errors.
    if (Files.notExists(file.toPath())) false else throw error
} catch (_: EOFException) {
    // The file was truncated while its JPEG markers were being read.
    false
}
