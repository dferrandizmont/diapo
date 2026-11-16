package io.github.dferrandizmont.carrete

import java.io.InputStream

internal fun checkImageSize(size: Long?, limit: Int) {
    if (size != null && size > limit) throw SecurityException("image too large")
}

/**
 * Known lengths normally need one exact allocation. Unknown or underreported
 * lengths grow geometrically, capped at the limit. A short result is trimmed to
 * the exact array length required by the channel.
 */
internal fun readBoundedImage(input: InputStream, size: Long?, limit: Int): ByteArray {
    checkImageSize(size, limit)
    var bytes = ByteArray(size?.takeIf { it >= 0 }?.toInt() ?: minOf(limit, 64 * 1024))
    var used = 0
    while (true) {
        if (used == bytes.size) {
            val next = input.read()
            if (next < 0) return bytes
            if (used == limit) throw SecurityException("image too large")
            // A provider can underreport its size. The stream limit still wins.
            val capacity = minOf(limit.toLong(), maxOf(64 * 1024L, 2L * bytes.size)).toInt()
            bytes = bytes.copyOf(capacity)
            bytes[used++] = next.toByte()
            continue
        }
        val read = input.read(bytes, used, minOf(64 * 1024, bytes.size - used))
        if (read < 0) return if (used == bytes.size) bytes else bytes.copyOf(used)
        if (read == 0) {
            val next = input.read()
            if (next < 0) return bytes.copyOf(used)
            bytes[used++] = next.toByte()
        } else used += read
    }
}
