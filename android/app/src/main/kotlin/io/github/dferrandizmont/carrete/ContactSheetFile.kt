package io.github.dferrandizmont.carrete

import java.io.File
import java.io.IOException
import java.nio.file.Files
import java.nio.file.InvalidPathException

/** Resolves only direct children of cache/contact-sheets, without traversal or symlinks. */
internal fun contactSheetFile(path: String, cacheDir: File): File = try {
    val cache = cacheDir.canonicalFile
    val folder = File(cache, "contact-sheets")
    val requested = File(path)
    if (!requested.isAbsolute || requested.toPath().any { it.toString() == ".." }) {
        throw SecurityException("not a contact sheet path")
    }
    if (Files.isSymbolicLink(folder.toPath()) || folder.canonicalFile != folder) {
        throw SecurityException("not a contact sheet folder")
    }
    val file = requested.canonicalFile
    if (file.parentFile != folder) {
        throw SecurityException("not a file of the contact sheet cache")
    }
    // Canonicalisation confines the target; also reject links that resolve
    // inside the folder. Stop at cache so OS aliases above it remain valid.
    var entry = requested.toPath().normalize().toFile()
    while (true) {
        if (Files.isSymbolicLink(entry.toPath())) throw SecurityException("symlink in contact sheet path")
        if (entry.canonicalFile == cache) break
        entry = entry.parentFile ?: throw SecurityException("not a cache path")
    }
    file
} catch (e: IOException) {
    throw SecurityException("cannot resolve contact sheet path", e)
} catch (e: InvalidPathException) {
    throw SecurityException("invalid contact sheet path", e)
}
