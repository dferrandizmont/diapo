package io.github.dferrandizmont.carrete

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/** One transient SAF grant per operation; no filesystem paths or new permissions. */
internal class SettingsBackupDocuments(private val activity: Activity) {
    // A stuck provider must not prevent the next operation or stream closure.
    private val worker = Executors.newCachedThreadPool { task ->
        Thread(task, "settings-documents").apply { isDaemon = true }
    }
    private val main = Handler(Looper.getMainLooper())
    private val session = SettingsBackupSession(
        schedule = { delay, action ->
            val task = Runnable { action() }
            main.postDelayed(task, delay)
            val cancel: () -> Unit = { main.removeCallbacks(task) }
            cancel
        },
        close = { stream -> worker.execute { runCatching { stream.close() } } },
    )

    fun saveState(out: Bundle) {
        val state = Bundle()
        state.putBoolean("interrupted", session.interrupted)
        session.pending?.saved?.let {
            state.putInt("request", it.request)
            state.putString("kind", if (it.request == CREATE) "export" else "import")
            state.putByteArray("bytes", it.bytes)
            state.putString("uri", it.uri)
        }
        out.putBundle(STATE, state)
    }

    fun restoreState(saved: Bundle?) {
        val state = saved?.getBundle(STATE) ?: return
        val request = state.getInt("request", 0)
        val operation = if (request == CREATE || request == OPEN) {
            SettingsBackupSession.Saved(request, state.getByteArray("bytes"), state.getString("uri"))
        } else null
        session.restore(operation, state.getBoolean("interrupted"))?.let { abandoned ->
            abandoned.uri?.let { cleanup(abandoned, Uri.parse(it)) }
        }
    }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (session.takeInterrupted()) {
            result.error("interrupted", "Previous settings document operation was interrupted", null)
            return
        }
        if (session.pending != null) {
            result.error("busy", "A settings document is already open", null)
            return
        }
        val exporting = call.method == "exportSettings"
        val bytes = if (exporting) call.argument<ByteArray>("bytes") else null
        val name = if (exporting) call.argument<String>("suggestedName") else null
        if (exporting && (bytes == null || name == null || !NAME.matches(name))) {
            result.error("invalid_arguments", "Invalid settings document", null)
            return
        }
        if (bytes != null && bytes.size > SettingsBackupBytes.MAX_BYTES) {
            result.error("too_large", "Settings document exceeds the size limit", null)
            return
        }
        val code = if (exporting) CREATE else OPEN
        val intent = Intent(if (exporting) Intent.ACTION_CREATE_DOCUMENT else Intent.ACTION_OPEN_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType("application/json")
        if (exporting) intent.putExtra(Intent.EXTRA_TITLE, name)
        val operation = session.begin(SettingsBackupSession.Saved(code, bytes)) { response, error ->
            if (error == null) result.success(response)
            else result.error(error, "Cannot complete settings document operation", null)
        }
        try {
            @Suppress("DEPRECATION")
            activity.startActivityForResult(intent, code)
        } catch (_: Exception) {
            session.finish(operation, null, "storage")
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        val operation = session.pending ?: return false
        if (requestCode != operation.saved.request) return false
        if (resultCode != Activity.RESULT_OK) {
            session.finish(operation, if (requestCode == CREATE) false else null, null)
            return true
        }
        val uri = data?.data
        if (uri == null) session.finish(operation, null, "storage")
        else {
            operation.saved.uri = uri.toString()
            access(operation, uri)
        }
        return true
    }

    private fun access(operation: SettingsBackupSession.Operation, uri: Uri) {
        session.watch(operation) { cleanup(operation.saved, uri) }
        worker.execute {
            try {
                val response = SettingsBackupIo.access(
                    operation,
                    exporting = operation.saved.request == CREATE,
                    openInput = { activity.contentResolver.openInputStream(uri) },
                    openOutput = { activity.contentResolver.openOutputStream(uri, "wt") },
                    deleteExport = { cleanup(operation.saved, uri) },
                )
                main.post { session.finish(operation, response, null) }
            } catch (_: SettingsBackupBytes.TooLarge) {
                main.post { session.finish(operation, null, "too_large") }
            } catch (_: Exception) {
                // Do not send provider exceptions: they may include paths or URIs.
                main.post { session.finish(operation, null, "storage") }
            }
        }
    }

    private fun cleanup(saved: SettingsBackupSession.Saved, uri: Uri) {
        if (saved.request != CREATE) return
        // A create picker may return an existing backup chosen for replacement.
        // Only an explicitly empty document is safe to remove on failure.
        runCatching {
            worker.execute {
                SettingsBackupIo.deleteEmptyExport(
                    isDocument = { DocumentsContract.isDocumentUri(activity, uri) },
                    size = {
                        activity.contentResolver.query(
                            uri, arrayOf(DocumentsContract.Document.COLUMN_SIZE), null, null, null,
                        )?.use { cursor ->
                            val column = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_SIZE)
                            if (cursor.moveToFirst() && column >= 0 && !cursor.isNull(column)) {
                                cursor.getLong(column)
                            } else null
                        }
                    },
                    delete = { DocumentsContract.deleteDocument(activity.contentResolver, uri) },
                )
            }
        }
    }

    fun dispose() {
        session.pending?.let { session.finish(it, null, "storage") }
        worker.shutdown()
    }

    companion object {
        private const val STATE = "carrete.settingsDocument"
        private const val CREATE = 48120
        private const val OPEN = 48121
        private val NAME = Regex("carrete-ajustes-[0-9]{4}-[0-9]{2}-[0-9]{2}\\.json")
    }
}
