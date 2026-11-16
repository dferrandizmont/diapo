package io.github.dferrandizmont.carrete

import java.io.Closeable

/** Lifecycle and timeout state independent of Android, with injectable scheduling. */
internal class SettingsBackupSession(
    private val schedule: (Long, () -> Unit) -> (() -> Unit),
    private val close: (Closeable) -> Unit,
) {
    data class Saved(val request: Int, val bytes: ByteArray?, var uri: String? = null)

    class Operation(val saved: Saved, val reply: ((Any?, String?) -> Unit)?) {
        private var cancelled = false
        private var stream: Closeable? = null
        var cancelTimeout: (() -> Unit)? = null

        @Synchronized fun attach(value: Closeable): Boolean {
            if (cancelled) return false
            stream = value
            return true
        }

        @Synchronized fun cancel(): Closeable? {
            cancelled = true
            return stream.also { stream = null }
        }
    }

    var pending: Operation? = null
        private set
    var interrupted = false
        private set

    fun begin(saved: Saved, reply: ((Any?, String?) -> Unit)?): Operation {
        check(pending == null)
        return Operation(saved, reply).also { pending = it }
    }

    /** Returns an abandoned document for cleanup; never resumes saved I/O. */
    fun restore(saved: Saved?, notice: Boolean): Saved? {
        interrupted = notice || saved != null
        if (saved?.uri != null) return saved
        if (saved != null) begin(saved, null)
        return null
    }

    fun takeInterrupted(): Boolean = interrupted.also { notice ->
        interrupted = false
        if (notice) {
            // The restored picker has no Dart caller. Do not leave it busy
            // indefinitely if its Activity result never arrives.
            pending?.takeIf { it.reply == null }?.let { finish(it, null, "interrupted") }
        }
    }

    fun watch(operation: Operation, onTimeout: () -> Unit) {
        operation.cancelTimeout = schedule(15_000) {
            if (pending === operation) {
                finish(operation, null, "storage")
                onTimeout()
            }
        }
    }

    fun finish(operation: Operation, response: Any?, error: String?): Boolean {
        if (pending !== operation) return false
        pending = null
        operation.cancelTimeout?.invoke()
        operation.cancel()?.let(close)
        operation.reply?.invoke(response, error)
        return true
    }
}
