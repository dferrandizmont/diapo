package io.github.dferrandizmont.carrete

import java.io.Closeable
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream

/** Provider access and conservative cleanup after failed or interrupted exports. */
internal object SettingsBackupIo {
    fun deleteEmptyExport(isDocument: () -> Boolean, size: () -> Long?, delete: () -> Unit) {
        // Unknown metadata or a failed query must preserve the user's document.
        runCatching {
            if (isDocument() && size() == 0L) delete()
        }
    }

    fun access(
        operation: SettingsBackupSession.Operation,
        exporting: Boolean,
        openInput: () -> InputStream?,
        openOutput: () -> OutputStream?,
        deleteExport: () -> Unit,
    ): Any {
        try {
            if (exporting) {
                val bytes = operation.saved.bytes ?: throw IOException("Missing settings bytes")
                val output = openOutput() ?: throw IOException("Cannot write settings document")
                use(operation, output) {
                    output.write(bytes)
                    output.flush()
                }
                return true
            }
            val input = openInput() ?: throw IOException("Cannot read settings document")
            return use(operation, input) { SettingsBackupBytes.read(input) }
        } catch (error: Exception) {
            if (exporting) deleteExport()
            throw error
        }
    }

    private fun <T> use(operation: SettingsBackupSession.Operation, stream: Closeable, action: () -> T): T =
        stream.use {
            if (!operation.attach(stream)) throw IOException("Operation interrupted")
            action()
        }
}
