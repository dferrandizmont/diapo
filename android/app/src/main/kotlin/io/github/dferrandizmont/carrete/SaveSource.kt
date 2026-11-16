package io.github.dferrandizmont.carrete

import java.io.File

/** Canonical EXIF source for either save protocol; never read outside the app cache. */
internal fun cacheSaveSource(sourcePath: String?, cacheDir: File): String? {
    if (sourcePath == null) return null
    val source = File(sourcePath).canonicalFile
    val cache = cacheDir.canonicalFile
    require(source.startsWith(cache) && source.isFile) { "not a file of the cache" }
    return source.path
}
