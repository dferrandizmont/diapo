package io.github.dferrandizmont.carrete

import android.content.Context
import android.content.res.AssetFileDescriptor
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.SoundPool
import android.os.Handler
import android.os.Looper
import io.flutter.FlutterInjector
import java.io.File
import java.io.IOException

/**
 * The short sounds of the camera, played with a [SoundPool]: the files are
 * decoded once when they are loaded, so a shot starts its click without delay.
 * It needs no permission. The ringer mode is read here too, so Dart can skip
 * the sounds when the phone is on silent or vibrate.
 *
 * Dart asks for a sound by name; only the names in [SOUNDS] exist, so no path
 * from the other side of the channel is ever opened.
 */
class CameraSounds(private val context: Context) {
    private val main = Handler(Looper.getMainLooper())
    private var pool: SoundPool? = null
    private val ids = HashMap<String, Int>()
    private val ready = HashSet<Int>()
    private val waiters = ArrayList<Waiter>()

    /** A call of [load] that waits for the decoding of some sounds. */
    private class Waiter(val pending: HashSet<Int>, val done: (Boolean) -> Unit) {
        var finished = false
        var failed = false
    }

    /** "silent", "vibrate" or "normal". */
    fun ringerMode(): String {
        val audio = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        return when (audio?.ringerMode) {
            AudioManager.RINGER_MODE_SILENT -> "silent"
            AudioManager.RINGER_MODE_VIBRATE -> "vibrate"
            else -> "normal"
        }
    }

    /**
     * Loads every sound and calls [done] on the main thread once they are all
     * decoded (true), or when one fails or [LOAD_TIMEOUT_MS] pass (false).
     */
    fun load(done: (Boolean) -> Unit) {
        val waiter: Waiter
        synchronized(this) {
            val soundPool = pool ?: create().also { pool = it }
            var failed = false
            for ((name, path) in SOUNDS) {
                if (ids.containsKey(name)) continue
                val id = try {
                    loadAsset(soundPool, path)
                } catch (e: IOException) {
                    0
                }
                if (id == 0) failed = true else ids[name] = id
            }
            val pending = HashSet(ids.values.filter { !ready.contains(it) })
            if (failed || pending.isEmpty()) {
                val ok = !failed
                main.post { done(ok) }
                return
            }
            waiter = Waiter(pending, done)
            waiters.add(waiter)
        }
        main.postDelayed({ finish(waiter, false) }, LOAD_TIMEOUT_MS)
    }

    /** Plays a loaded sound once. False when it is not loaded (yet). */
    @Synchronized
    fun play(name: String): Boolean {
        val id = ids[name] ?: return false
        if (!ready.contains(id)) return false
        return pool?.play(id, 1f, 1f, 1, 0, 1f) != 0
    }

    @Synchronized
    fun release() {
        pool?.release()
        pool = null
        ids.clear()
        ready.clear()
        waiters.clear()
    }

    private fun finish(waiter: Waiter, ok: Boolean) {
        synchronized(this) {
            if (waiter.finished) return
            waiter.finished = true
            waiters.remove(waiter)
        }
        waiter.done(ok)
    }

    private fun onLoaded(id: Int, success: Boolean) {
        val finished = ArrayList<Pair<Waiter, Boolean>>()
        synchronized(this) {
            if (success) {
                ready.add(id)
            } else {
                // Forget it, so the next load tries again.
                ids.values.remove(id)
            }
            for (waiter in waiters) {
                if (!waiter.pending.contains(id)) continue
                if (success) waiter.pending.remove(id) else waiter.failed = true
                if (waiter.failed || waiter.pending.isEmpty()) {
                    finished.add(Pair(waiter, !waiter.failed))
                }
            }
        }
        for ((waiter, ok) in finished) main.post { finish(waiter, ok) }
    }

    private fun create(): SoundPool {
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        return SoundPool.Builder()
            .setMaxStreams(3)
            .setAudioAttributes(attributes)
            .build()
            .also { soundPool ->
                soundPool.setOnLoadCompleteListener { _, id, status -> onLoaded(id, status == 0) }
            }
    }

    private fun loadAsset(soundPool: SoundPool, path: String): Int {
        val key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(path)
        return try {
            context.assets.openFd(key).use { descriptor: AssetFileDescriptor ->
                soundPool.load(descriptor, 1)
            }
        } catch (e: IOException) {
            // A compressed asset has no file descriptor: copy it to the cache.
            val copy = File(context.cacheDir, "sound_" + path.replace('/', '_'))
            context.assets.open(key).use { input ->
                copy.outputStream().use { output -> input.copyTo(output) }
            }
            // The copy stays in the cache: the pool decodes it in the background.
            soundPool.load(copy.absolutePath, 1)
        }
    }

    companion object {
        /** The only sounds there are: name to Flutter asset. */
        private val SOUNDS = linkedMapOf(
            "shutter" to "assets/sounds/shutter.wav",
            "advance" to "assets/sounds/advance.wav",
            "cartridge" to "assets/sounds/cartridge.wav",
            "load" to "assets/sounds/load.wav",
            "rewind" to "assets/sounds/rewind.wav",
        )

        private const val LOAD_TIMEOUT_MS = 3000L
    }
}
