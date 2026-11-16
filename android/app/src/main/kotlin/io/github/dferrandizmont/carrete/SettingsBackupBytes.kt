package io.github.dferrandizmont.carrete

import java.io.ByteArrayOutputStream
import java.io.InputStream

/** Bounds memory even when a document provider omits or lies about its size. */
internal object SettingsBackupBytes {
    const val MAX_BYTES = 256 * 1024

    class TooLarge : Exception()

    fun read(input: InputStream): ByteArray {
        val output = ByteArrayOutputStream()
        val buffer = ByteArray(8192)
        while (true) {
            // At most one byte beyond the limit is read, never buffered in full.
            val count = input.read(buffer, 0, minOf(buffer.size, MAX_BYTES - output.size() + 1))
            if (count == -1) return output.toByteArray()
            if (output.size() + count > MAX_BYTES) throw TooLarge()
            output.write(buffer, 0, count)
        }
    }
}
