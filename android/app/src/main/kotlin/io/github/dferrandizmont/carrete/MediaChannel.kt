package io.github.dferrandizmont.carrete

import android.app.Activity
import android.app.RecoverableSecurityException
import android.content.ClipData
import android.content.ContentValues
import android.content.ContentResolver
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.content.IntentSender
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.util.Size
import androidx.core.content.FileProvider
import androidx.exifinterface.media.ExifInterface
import io.flutter.plugin.common.BasicMessageChannel
import io.flutter.plugin.common.BinaryCodec
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileNotFoundException
import java.io.FileOutputStream
import java.nio.ByteOrder
import java.nio.ByteBuffer
import java.nio.charset.StandardCharsets
import java.util.ArrayDeque
import java.util.concurrent.ExecutorService
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * Encodes rendered RGBA pixels as JPEG, carries over the EXIF of the camera
 * original (orientation reset: the pixels are already upright; GPS only on
 * request) and adds the file to the gallery in Pictures/Diapo. The untouched
 * camera original can go too, only into its subfolder Pictures/Diapo/Originales
 * (see [saveOriginal]). Contact sheets use a separate cache-only byte encoder.
 *
 * Production stills use `beginTiledSave`, then `carrete/media/tiles`: a
 * token/x/y/width/height little-endian header followed by one RGBA tile. One
 * native bitmap receives all tiles; only the last tile encodes and publishes.
 * Incomplete saves are cancelled or recycled when a new save begins/disposes.
 *
 * The benchmark also supports two messages from Dart, in order:
 *
 * 1. `beginSave` on the method channel `carrete/media`, with the metadata
 *    (size, quality, name, source path, `includeLocation`). It queues a
 *    [PendingSave] and answers with its token.
 * 2. The pixels alone on the binary channel `carrete/media/pixels`, with
 *    [BinaryCodec.INSTANCE_DIRECT]: a direct ByteBuffer that stays in native
 *    memory, instead of the Java-heap `byte[]` that the standard codec would
 *    build (200 MB for a 50 MP still, enough for an OutOfMemoryError). The
 *    buffer is only valid inside the handler, so the pixels go into a Bitmap
 *    (native memory too) right there; the slow work runs on a worker thread.
 *    The reply is a UTF-8 JSON object: the timings and the URI, or an error.
 */
class MediaChannel(
    private val context: Context,
    /** The activity that can show the share sheet and the delete dialog, when there is one. */
    private val activityProvider: () -> Activity? = { null },
) : MethodChannel.MethodCallHandler {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val pending = ArrayDeque<PendingSave>()
    private var nextToken = 1

    private class PendingSave(
        val token: Int,
        val width: Int,
        val height: Int,
        val quality: Int,
        val name: String,
        val sourcePath: String?,
        val includeLocation: Boolean,
        val location: PhotoLocation?,
        val takenAt: Long?,
    )

    private class TiledSave(
        val save: PendingSave,
        val raster: TileRaster,
        val bitmap: Bitmap,
    )
    private var tiled: TiledSave? = null

    // All tiled state and this watchdog run on the platform's main looper.
    private val tiledWatchdog = Runnable { clearTiled() }

    private fun touchTiled() {
        main.removeCallbacks(tiledWatchdog)
        main.postDelayed(tiledWatchdog, 60_001L)
    }

    private fun detachTiled() {
        main.removeCallbacks(tiledWatchdog)
        tiled = null
    }

    private fun clearTiled() {
        tiled?.bitmap?.recycle()
        detachTiled()
    }

    /** Registers all channels on [messenger]. */
    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, "carrete/media").setMethodCallHandler(this)
        BasicMessageChannel(messenger, "carrete/media/pixels", BinaryCodec.INSTANCE_DIRECT)
            .setMessageHandler { message, reply -> onPixels(message, reply) }
        BasicMessageChannel(messenger, "carrete/media/tiles", BinaryCodec.INSTANCE_DIRECT)
            .setMessageHandler { message, reply -> onTilePixels(message, reply) }
        BasicMessageChannel(messenger, "carrete/media/contact-sheet", BinaryCodec.INSTANCE_DIRECT)
            .setMessageHandler { message, reply -> onContactSheetPixels(message, reply) }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "findSaved" -> {
                val name = call.argument<String>("displayName")
                if (name == null || !name.matches(Regex("CARRETE_[A-Za-z0-9_]+"))) {
                    result.error("bad_arguments", "Invalid display name", null)
                    return
                }
                val folder = if (call.argument<Boolean>("original") == true) ORIGINALS_FOLDER else ALBUM_FOLDER
                worker.execute {
                    try {
                        val uri = findSaved(name, folder)
                        main.post { result.success(uri) }
                    } catch (e: Throwable) {
                        main.post { result.error("lookup_failed", e.message, null) }
                    }
                }
            }
            "beginSave" -> {
                try {
                    val width = requireNotNull(call.argument<Int>("width"))
                    val height = requireNotNull(call.argument<Int>("height"))
                    TileRaster.validateDimensions(width, height)
                    val name = requireNotNull(call.argument<String>("displayName"))
                    require(name.matches(DEVELOPED_NAME)) { "bad display name" }
                    val takenAt = call.argument<Any?>("takenAt")
                    val save = PendingSave(
                        token = nextToken++,
                        width = width,
                        height = height,
                        quality = call.argument<Int>("quality") ?: 95,
                        name = name,
                        sourcePath = cacheSaveSource(call.argument<String>("sourcePath"), context.cacheDir),
                        includeLocation = ExifCopy.allowsLocation(
                            call.argument<Boolean>("includeLocation") == true, call.hasArgument("takenAt"), takenAt,
                        ),
                        location = PhotoLocation.from(call.argument<Map<*, *>>("location")),
                        takenAt = (takenAt as? Number)?.toLong(),
                    )
                    // Only one save is in flight at a time (the capture queue
                    // is sequential); a stale entry means its pixels never
                    // arrived, so it must not pair with the next ones.
                    clearTiled()
                    pending.clear()
                    pending.addLast(save)
                    result.success(save.token)
                } catch (e: Throwable) {
                    result.error("bad_arguments", e.message, null)
                }
            }
            "beginTiledSave" -> {
                try {
                    clearTiled()
                    pending.clear()
                    val width = requireNotNull(call.argument<Int>("width"))
                    val height = requireNotNull(call.argument<Int>("height"))
                    val raster = TileRaster(
                        width, height, requireNotNull(call.argument<Int>("tileSize")),
                        framed = call.argument<Boolean>("framed") == true,
                    )
                    val name = requireNotNull(call.argument<String>("displayName"))
                    require(name.matches(DEVELOPED_NAME)) { "bad display name" }
                    val takenAt = call.argument<Any?>("takenAt")
                    val save = PendingSave(
                        token = nextToken++,
                        width = width,
                        height = height,
                        quality = (call.argument<Int>("quality") ?: 95).coerceIn(1, 100),
                        name = name,
                        sourcePath = cacheSaveSource(call.argument<String>("sourcePath"), context.cacheDir),
                        includeLocation = ExifCopy.allowsLocation(
                            call.argument<Boolean>("includeLocation") == true, call.hasArgument("takenAt"), takenAt,
                        ),
                        location = PhotoLocation.from(call.argument<Map<*, *>>("location")),
                        takenAt = (takenAt as? Number)?.toLong(),
                    )
                    tiled = TiledSave(
                        save, raster, Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888),
                    )
                    touchTiled()
                    result.success(save.token)
                } catch (e: Throwable) {
                    clearTiled()
                    result.error("save_failed", e.toString(), null)
                }
            }
            "cancelTiledSave" -> {
                if (tiled?.save?.token == call.argument<Int>("token")) clearTiled()
                result.success(null)
            }
            "saveOriginal" -> {
                val source = call.argument<String>("sourcePath")
                val name = call.argument<String>("displayName")
                if (source == null || name == null || !name.matches(ORIGINAL_NAME)) {
                    result.error("bad_arguments", "Invalid original", null)
                    return
                }
                val takenAt = call.argument<Any?>("takenAt")
                val includeLocation = ExifCopy.allowsLocation(
                    call.argument<Boolean>("includeLocation") == true, call.hasArgument("takenAt"), takenAt,
                )
                val location = PhotoLocation.from(call.argument<Map<*, *>>("location"))
                worker.execute {
                    try {
                        val uri = saveOriginal(source, name, includeLocation, location, (takenAt as? Number)?.toLong())
                        main.post { result.success(uri) }
                    } catch (e: Throwable) {
                        main.post { result.error("save_failed", e.toString(), null) }
                    }
                }
            }
            "readExifDates" -> {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("bad_arguments", "no path", null)
                    return
                }
                readExifDates(path, result)
            }
            else -> onViewerCall(call, result)
        }
    }

    /**
     * The capture dates of a photo that sits in the cache of the app (the
     * copy of a photo picked to be developed): the raw EXIF strings
     * `original` and `digitized` with their offsets (`originalOffset`,
     * `digitizedOffset`), each null when the photo has none. Dart chooses
     * between them. Anything outside the cache answers `not_allowed`.
     */
    private fun readExifDates(path: String, result: MethodChannel.Result) {
        reader.execute {
            try {
                val file = File(path).canonicalFile
                val cache = context.cacheDir.canonicalFile
                if (file.parentFile?.canonicalFile?.startsWith(cache) != true || !file.isFile) {
                    main.post { result.error("not_allowed", "not a file of the cache", null) }
                    return@execute
                }
                val exif = ExifInterface(file.absolutePath)
                val dates = hashMapOf<String, String?>(
                    "original" to exif.getAttribute(ExifInterface.TAG_DATETIME_ORIGINAL),
                    "originalOffset" to exif.getAttribute(ExifInterface.TAG_OFFSET_TIME_ORIGINAL),
                    "digitized" to exif.getAttribute(ExifInterface.TAG_DATETIME_DIGITIZED),
                    "digitizedOffset" to exif.getAttribute(ExifInterface.TAG_OFFSET_TIME_DIGITIZED),
                )
                main.post { result.success(dates) }
            } catch (e: Throwable) {
                main.post { result.error("read_failed", e.toString(), null) }
            }
        }
    }

    /** A 12-byte width/height/quality LE header, then RGBA; replies with JPEG or null. */
    private fun onContactSheetPixels(message: ByteBuffer?, reply: BasicMessageChannel.Reply<ByteBuffer>) {
        var bitmap: Bitmap? = null
        try {
            val pixels = requireNotNull(message).order(ByteOrder.LITTLE_ENDIAN)
            require(pixels.remaining() >= 12) { "no contact sheet header" }
            val width = pixels.int
            val height = pixels.int
            val quality = pixels.int
            validateContactSheetDimensions(width, height)
            require(quality in 1..100) { "bad JPEG quality" }
            require(pixels.remaining().toLong() == width.toLong() * height * 4L) { "bad RGBA bytes" }
            val image = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            bitmap = image
            image.copyPixelsFromBuffer(pixels)
            // Consume the direct input before returning from this handler.
            // Only compressed bytes go on the Java heap; no MediaStore or EXIF.
            worker.execute {
                val out = try {
                    ByteArrayOutputStream().use { stream ->
                        check(image.compress(Bitmap.CompressFormat.JPEG, quality, stream))
                        val bytes = stream.toByteArray()
                        ByteBuffer.allocateDirect(bytes.size).apply { put(bytes) }
                    }
                } catch (e: Throwable) {
                    null
                } finally {
                    image.recycle()
                }
                main.post { reply.reply(out) }
            }
        } catch (e: Throwable) {
            bitmap?.recycle()
            reply.reply(null)
        }
    }

    private fun onPixels(message: ByteBuffer?, reply: BasicMessageChannel.Reply<ByteBuffer>) {
        val save = pending.pollFirst()
        if (save == null) {
            reply.reply(errorReply("no pending save for the pixels"))
            return
        }
        val bitmap: Bitmap
        try {
            val pixels = requireNotNull(message) { "no pixels" }
            val expected = save.width.toLong() * save.height.toLong() * 4L
            val got = pixels.remaining().toLong()
            require(got == expected) { "expected $expected bytes of RGBA, got $got" }
            bitmap = Bitmap.createBitmap(save.width, save.height, Bitmap.Config.ARGB_8888)
            bitmap.copyPixelsFromBuffer(pixels)
        } catch (e: Throwable) {
            // An OutOfMemoryError included: the Dart side keeps the original.
            reply.reply(errorReply(e.toString()))
            return
        }
        worker.execute {
            val out = try {
                encodeAndPublish(bitmap, save)
            } catch (e: Throwable) {
                errorReply(e.toString())
            } finally {
                bitmap.recycle()
            }
            main.post { reply.reply(out) }
        }
    }

    /** Each direct buffer is consumed during the handler; it is never retained. */
    private fun onTilePixels(message: ByteBuffer?, reply: BasicMessageChannel.Reply<ByteBuffer>) {
        val session = tiled
        if (session == null) {
            reply.reply(errorReply("no pending tiled save"))
            return
        }
        try {
            val pixels = requireNotNull(message).order(ByteOrder.LITTLE_ENDIAN)
            require(pixels.remaining() >= 20) { "no tile header" }
            val token = pixels.int
            // A delayed message cannot corrupt or release a newer save.
            if (token != session.save.token) {
                reply.reply(errorReply("stale tile token"))
                return
            }
            val x = pixels.int
            val y = pixels.int
            val w = pixels.int
            val h = pixels.int
            session.raster.copy(x, y, w, h, pixels) { left, top, row ->
                session.bitmap.setPixels(row, 0, row.size, left, top, row.size, 1)
            }
            if (!session.raster.complete) {
                touchTiled()
                reply.reply(json(JSONObject().put("ok", true)))
                return
            }
            // Retain ownership until execute accepts. Rejection falls through
            // to clearTiled, which still owns and recycles the bitmap.
            worker.execute {
                val out = try {
                    encodeAndPublish(session.bitmap, session.save)
                } catch (e: Throwable) {
                    errorReply(e.toString())
                } finally {
                    session.bitmap.recycle()
                }
                main.post { reply.reply(out) }
            }
            detachTiled()
        } catch (e: Throwable) {
            clearTiled()
            reply.reply(errorReply(e.toString()))
        }
    }

    private fun encodeAndPublish(bitmap: Bitmap, save: PendingSave): ByteBuffer {
        val tmp = File(context.cacheDir, "${save.name}.jpg")
        try {
            var t = SystemClock.elapsedRealtime()
            FileOutputStream(tmp).use { bitmap.compress(Bitmap.CompressFormat.JPEG, save.quality, it) }
            val encodeMs = SystemClock.elapsedRealtime() - t

            t = SystemClock.elapsedRealtime()
            if (save.sourcePath != null) {
                copyExif(save.sourcePath, tmp, save.width, save.height, save.includeLocation, save.location, save.takenAt)
            }
            val exifMs = SystemClock.elapsedRealtime() - t

            t = SystemClock.elapsedRealtime()
            val uri = publish(tmp, save.name, ALBUM_FOLDER)
            val writeMs = SystemClock.elapsedRealtime() - t

            return json(
                JSONObject()
                    .put("ok", true)
                    .put("encodeMs", encodeMs)
                    .put("exifMs", exifMs)
                    .put("writeMs", writeMs)
                    .put("uri", uri),
            )
        } finally {
            tmp.delete()
        }
    }

    private fun copyExif(
        sourcePath: String,
        target: File,
        width: Int,
        height: Int,
        includeLocation: Boolean,
        location: PhotoLocation?,
        takenAt: Long?,
    ) {
        // A source ExifInterface cannot read (a PNG or WebP picked to be
        // developed) has no tags to carry over; the photo is still saved.
        val src = try {
            ExifInterface(sourcePath)
        } catch (e: java.io.IOException) {
            null
        }
        val dst = ExifInterface(target.absolutePath)
        if (src != null) ExifCopy.copy(src, dst, includeLocation)
        if (includeLocation && location != null) ExifCopy.writeLocation(true, location, takenAt, dst::setAttribute)
        dst.setAttribute(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL.toString())
        dst.setAttribute(ExifInterface.TAG_IMAGE_WIDTH, width.toString())
        dst.setAttribute(ExifInterface.TAG_IMAGE_LENGTH, height.toString())
        dst.setAttribute(ExifInterface.TAG_PIXEL_X_DIMENSION, width.toString())
        dst.setAttribute(ExifInterface.TAG_PIXEL_Y_DIMENSION, height.toString())
        dst.setAttribute(ExifInterface.TAG_SOFTWARE, "Diapo")
        dst.saveAttributes()
    }

    /**
     * Copies the camera JPEG at [sourcePath] as it is (EXIF included) into the
     * originals folder as [name], and answers its location. The GPS tags are
     * removed from the copy unless [includeLocation]. A name that is already
     * saved answers the existing item. Only a JPEG that sits in the cache of
     * the app is accepted: the files of the user are never read from here.
     */
    private fun saveOriginal(sourcePath: String, name: String, includeLocation: Boolean, location: PhotoLocation?, takenAt: Long?): String {
        findSaved(name, ORIGINALS_FOLDER)?.let { return it }
        val source = File(sourcePath).canonicalFile
        val cache = context.cacheDir.canonicalFile
        require(source.startsWith(cache) && source.isFile) { "not a file of the cache" }
        require(source.length() in 4..MAX_IMAGE_BYTES.toLong()) { "bad size" }
        java.io.RandomAccessFile(source, "r").use {
            require(it.readUnsignedShort() == 0xffd8) { "not a JPEG" }
        }
        // Its own folder, swept by the app at start: nothing else is staged there.
        val staging = File(cache, ORIGINAL_TEMP_FOLDER)
        staging.mkdirs()
        val tmp = File(staging, "$name.jpg")
        try {
            source.copyTo(tmp, overwrite = true)
            if (!includeLocation || location != null) {
                val exif = ExifInterface(tmp.absolutePath)
                ExifCopy.writeLocation(includeLocation, location, takenAt, exif::setAttribute)
                exif.saveAttributes()
            }
            return publish(tmp, name, ORIGINALS_FOLDER)
        } finally {
            tmp.delete()
        }
    }

    private fun publish(file: File, name: String, folder: String): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = context.contentResolver
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, "$name.jpg")
                put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
                put(MediaStore.Images.Media.RELATIVE_PATH, "${Environment.DIRECTORY_PICTURES}/$folder/")
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
            val collection = MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            val uri: Uri = resolver.insert(collection, values) ?: error("MediaStore insert failed")
            try {
                resolver.openOutputStream(uri)!!.use { out -> file.inputStream().use { it.copyTo(out) } }
                values.clear()
                values.put(MediaStore.Images.Media.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
            } catch (e: Throwable) {
                // No row left behind at IS_PENDING=1 (an invisible, empty entry).
                try {
                    resolver.delete(uri, null, null)
                } catch (_: Throwable) {
                }
                throw e
            }
            return uri.toString()
        }
        // Android 8-9: needs WRITE_EXTERNAL_STORAGE (maxSdkVersion 28).
        @Suppress("DEPRECATION")
        val dir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES), folder)
        dir.mkdirs()
        val dest = File(dir, "$name.jpg")
        file.copyTo(dest, overwrite = true)
        MediaScannerConnection.scanFile(context, arrayOf(dest.absolutePath), arrayOf("image/jpeg"), null)
        return dest.absolutePath
    }

    private fun findSaved(name: String, folder: String): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            @Suppress("DEPRECATION")
            val directory = File(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES),
                folder,
            )
            val file = File(directory, "$name.jpg")
            // A process can die in copyTo on Android 8-9. A truncated JPEG
            // must be overwritten rather than accepted as a finished export.
            return if (isSavedJpeg(file)) file.absolutePath else null
        }
        val resolver = context.contentResolver
        val collection = MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val projection = arrayOf(MediaStore.Images.Media._ID, MediaStore.Images.Media.IS_PENDING)
        val selection = "${MediaStore.Images.Media.DISPLAY_NAME} = ? AND " +
            "${MediaStore.Images.Media.RELATIVE_PATH} = ?"
        val args = arrayOf("$name.jpg", "${Environment.DIRECTORY_PICTURES}/$folder/")
        // No read permission: MediaStore exposes this app's own exports. Include
        // pending rows so an interrupted write can be removed before retrying.
        val cursor = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            resolver.query(collection, projection, Bundle().apply {
                putString(ContentResolver.QUERY_ARG_SQL_SELECTION, selection)
                putStringArray(ContentResolver.QUERY_ARG_SQL_SELECTION_ARGS, args)
                putInt(MediaStore.QUERY_ARG_MATCH_PENDING, MediaStore.MATCH_INCLUDE)
            }, null)
        } else {
            @Suppress("DEPRECATION")
            resolver.query(MediaStore.setIncludePending(collection), projection, selection, args, null)
        } ?: error("MediaStore query failed")
        val unfinished = mutableListOf<Uri>()
        var saved: String? = null
        cursor.use {
            while (it.moveToNext()) {
                val uri = ContentUris.withAppendedId(collection, it.getLong(0))
                if (it.getInt(1) == 0) saved = saved ?: uri.toString()
                else unfinished.add(uri)
            }
        }
        for (uri in unfinished) resolver.delete(uri, null, null)
        return saved
    }

    private fun errorReply(message: String): ByteBuffer =
        json(JSONObject().put("ok", false).put("error", message))

    private fun json(obj: JSONObject): ByteBuffer {
        val bytes = obj.toString().toByteArray(StandardCharsets.UTF_8)
        // The engine reads a direct buffer from position 0 to its position.
        return ByteBuffer.allocateDirect(bytes.size).apply { put(bytes) }
    }

    // --- reading the saved photos back (contact sheet and viewer) ------------
    //
    // `loadThumbnail` (uri, extent) and `readImage` (uri) answer with JPEG
    // bytes. Only the photos of the app itself are served: the items of
    // Pictures/Diapo (a content URI on Android 10+, a file path on 8-9).
    // Reading them needs no permission. A missing item answers `not_found`.

    private val reader: ExecutorService = Executors.newFixedThreadPool(2)

    private fun onViewerCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "loadThumbnail" -> readerTask(result) {
                loadThumbnail(
                    call.argument<String>("uri")!!,
                    (call.argument<Int>("extent") ?: 320).coerceIn(1, MAX_THUMBNAIL_EXTENT),
                )
            }
            "readImage" -> readerTask(result) { readImage(call.argument<String>("uri")!!) }
            "shareImage" -> withUri(call, result) { shareImage(it, result) }
            "shareFile" -> {
                val path = call.argument<String>("path")
                if (path == null) result.error("bad_arguments", "no path", null) else shareFile(path, result)
            }
            "deleteImage" -> withUri(call, result) { deleteImage(it, result) }
            "missingImages" -> {
                val uris = call.argument<List<String>>("uris")
                if (uris == null) result.error("bad_arguments", "no uris", null) else missingImages(uris, result)
            }
            else -> result.notImplemented()
        }
    }

    private fun withUri(call: MethodCall, result: MethodChannel.Result, block: (String) -> Unit) {
        val uri = call.argument<String>("uri")
        if (uri == null) result.error("bad_arguments", "no uri", null) else block(uri)
    }

    private fun readerTask(result: MethodChannel.Result, work: () -> ByteArray) {
        reader.execute {
            try {
                val bytes = work()
                main.post { result.success(bytes) }
            } catch (e: FileNotFoundException) {
                main.post { result.error("not_found", e.message, null) }
            } catch (e: SecurityException) {
                main.post { result.error("not_allowed", e.message, null) }
            } catch (e: NotOwnItemException) {
                main.post { result.error("not_allowed", e.message, null) }
            } catch (e: Throwable) {
                main.post { result.error("read_failed", e.toString(), null) }
            }
        }
    }

    private class OwnItem(val uri: Uri?, val file: File?)

    /** The item is not one of this app's album (a bad URI, or outside Pictures/Diapo). */
    private class NotOwnItemException(message: String) : Exception(message)

    /**
     * The single-image URI behind [location], rebuilt from its numeric id, or
     * null when [location] is anything else: another authority, a collection,
     * extra path segments, a query or a fragment. Only
     * `content://media/<volume>/images/media/<id>` passes.
     */
    private fun imageUriOf(location: String): Uri? {
        val uri = Uri.parse(location)
        if (uri.scheme != "content" || uri.authority != MediaStore.AUTHORITY) return null
        if (uri.query != null || uri.fragment != null) return null
        val segments = uri.pathSegments
        if (segments.size != 4 || segments[1] != "images" || segments[2] != "media") return null
        if (segments[0] != MediaStore.VOLUME_EXTERNAL_PRIMARY && segments[0] != MediaStore.VOLUME_EXTERNAL) return null
        val id = segments[3].takeIf { it.isNotEmpty() && it.all { c -> c in '0'..'9' } }?.toLongOrNull() ?: return null
        return ContentUris.withAppendedId(MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY), id)
    }

    /**
     * Accepts only the items of this app's own album; anything else throws
     * [NotOwnItemException]. A photo that is not there throws
     * [FileNotFoundException].
     */
    private fun ownItem(location: String): OwnItem {
        val album = "${Environment.DIRECTORY_PICTURES}/Diapo"
        if (location.startsWith("content://")) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) throw NotOwnItemException("not an item of the media store")
            val uri = imageUriOf(location) ?: throw NotOwnItemException("not an image of the media store")
            val cursor = context.contentResolver.query(
                uri,
                arrayOf(MediaStore.MediaColumns.RELATIVE_PATH),
                null,
                null,
                null,
            ) ?: throw FileNotFoundException(location)
            cursor.use {
                if (!it.moveToFirst()) throw FileNotFoundException(location)
                val folder = (it.getString(0) ?: "").trimEnd('/')
                if (folder != album) throw NotOwnItemException("outside $album")
            }
            return OwnItem(uri, null)
        }
        @Suppress("DEPRECATION")
        val dir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES), "Diapo")
        val file = File(location).canonicalFile
        if (file.parentFile != dir.canonicalFile) throw NotOwnItemException("outside $album")
        if (!file.isFile) throw FileNotFoundException(location)
        return OwnItem(null, file)
    }

    private fun loadThumbnail(location: String, extent: Int): ByteArray {
        val item = ownItem(location)
        val bitmap: Bitmap =
            if (item.uri != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                context.contentResolver.loadThumbnail(item.uri, Size(extent, extent), null)
            } else {
                decodeSampled(item.file!!, extent)
            }
        try {
            val out = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.JPEG, 85, out)
            return out.toByteArray()
        } finally {
            bitmap.recycle()
        }
    }

    /** Decodes [file] at the largest power-of-two reduction that keeps [extent] pixels. */
    private fun decodeSampled(file: File, extent: Int): Bitmap {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.absolutePath, bounds)
        var sample = 1
        while (bounds.outWidth / (sample * 2) >= extent && bounds.outHeight / (sample * 2) >= extent) {
            sample *= 2
        }
        val options = BitmapFactory.Options().apply { inSampleSize = sample }
        return BitmapFactory.decodeFile(file.absolutePath, options)
            ?: throw FileNotFoundException(file.path)
    }

    private fun readImage(location: String): ByteArray {
        val item = ownItem(location)
        if (item.uri != null) {
            val resolver = context.contentResolver
            val size = try {
                resolver.query(item.uri, arrayOf(OpenableColumns.SIZE), null, null, null)?.use {
                    if (it.moveToFirst() && !it.isNull(0)) it.getLong(0) else null
                }
            } catch (_: IllegalArgumentException) {
                null // Some providers do not expose a size column.
            } catch (_: UnsupportedOperationException) {
                null
            }
            checkImageSize(size, MAX_IMAGE_BYTES)
            val descriptor = resolver.openAssetFileDescriptor(item.uri, "r")
                ?: throw FileNotFoundException(location)
            return descriptor.use {
                checkImageSize(it.length, MAX_IMAGE_BYTES)
                val length = it.length.takeIf { length -> length >= 0 } ?: size
                it.createInputStream().use { stream -> readBoundedImage(stream, length, MAX_IMAGE_BYTES) }
            }
        }
        val file = item.file!!
        val size = file.length()
        checkImageSize(size, MAX_IMAGE_BYTES)
        return file.inputStream().use { readBoundedImage(it, size, MAX_IMAGE_BYTES) }
    }

    // --- sharing and deleting ------------------------------------------------
    //
    // `shareImage` (uri) opens the share sheet with the photo itself: the same
    // `content://` item the gallery holds, read by the target app through a
    // temporary grant. `deleteImage` (uri) answers `deleted`, `gone` (it was
    // not there any more) or `cancelled` (the user refused the system dialog).
    // `missingImages` (uris) answers which of the photos are certainly not in
    // the media store any more. All three only touch the items of this app's
    // own album (see [ownItem]); the system confirmation of a delete is asked
    // only for an item that passed that check.

    private fun shareImage(location: String, result: MethodChannel.Result) {
        reader.execute {
            try {
                val item = ownItem(location)
                val uri = item.uri ?: contentUriOf(item.file!!)
                main.post { result.success(launchShare(uri)) }
            } catch (e: FileNotFoundException) {
                main.post { result.error("not_found", e.message, null) }
            } catch (e: NotOwnItemException) {
                main.post { result.error("not_allowed", e.message, null) }
            } catch (e: Throwable) {
                main.post { result.error("share_failed", e.toString(), null) }
            }
        }
    }

    private fun shareFile(path: String, result: MethodChannel.Result) {
        reader.execute {
            try {
                val file = contactSheetFile(path, context.cacheDir)
                val mime = when (file.extension.lowercase()) {
                    "jpg", "jpeg" -> "image/jpeg"
                    "png" -> "image/png"
                    else -> throw SecurityException("not a contact sheet image")
                }
                if (!file.isFile) throw FileNotFoundException("contact sheet not found")
                val uri = FileProvider.getUriForFile(context, "${context.packageName}.sheets", file)
                main.post { result.success(launchShare(uri, mime)) }
            } catch (e: SecurityException) {
                main.post { result.error("not_allowed", e.message, null) }
            } catch (e: FileNotFoundException) {
                main.post { result.error("not_found", e.message, null) }
            } catch (e: Throwable) {
                main.post { result.error("share_failed", e.toString(), null) }
            }
        }
    }

    private fun launchShare(uri: Uri, mime: String = "image/jpeg"): Boolean {
        val send = Intent(Intent.ACTION_SEND).apply {
            type = mime
            putExtra(Intent.EXTRA_STREAM, uri)
            clipData = ClipData.newRawUri(null, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        val chooser = Intent.createChooser(send, null)
        val activity = activityProvider()
        return try {
            if (activity != null) {
                activity.startActivity(chooser)
            } else {
                context.startActivity(chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            }
            true
        } catch (e: Exception) {
            false
        }
    }

    /** The content URI of a file of the album on Android 8-9, where the gallery keeps paths. */
    private fun contentUriOf(file: File): Uri {
        val found = arrayOfNulls<Uri>(1)
        val done = CountDownLatch(1)
        MediaScannerConnection.scanFile(context, arrayOf(file.absolutePath), arrayOf("image/jpeg")) { _, uri ->
            found[0] = uri
            done.countDown()
        }
        done.await(5, TimeUnit.SECONDS)
        return found[0] ?: throw FileNotFoundException(file.path)
    }

    /**
     * What a delete is waiting for while the system dialog is on screen.
     * [original] is the untouched original saved with the photo, if any; it
     * goes with it.
     */
    private class PendingDelete(
        val uri: Uri,
        val original: Uri?,
        /** An original that is not ours is never deleted: the answer says it stays. */
        val originalStays: Boolean,
        val result: MethodChannel.Result,
        val retryAfterGrant: Boolean,
    )

    private var pendingDelete: PendingDelete? = null

    private fun deleteImage(location: String, result: MethodChannel.Result) {
        reader.execute {
            try {
                val item = ownItem(location)
                if (item.uri == null) {
                    // Android 8-9: the app wrote the file, so it can remove it.
                    // So is the original next to it, if there is one.
                    val original = originalFileOf(item.file!!)
                    deleteFile(item.file)
                    val kept = original != null && !removed { deleteFile(original) }
                    main.post { result.success(if (kept) KEPT_ORIGINAL else "deleted") }
                    return@execute
                }
                // Found before the photo goes: its name is how it is found. Only
                // an original this app wrote goes with it (or is asked about);
                // any other stays, and the answer says so.
                val found = originalUriOf(item.uri)
                val original = found?.takeIf { ownedByApp(it) }
                val originalStays = found != null && original == null
                val both = listOfNotNull(item.uri, original)
                // Android 11+: when the system would have to ask about either
                // of them, it asks once about both, so the pair stays together.
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && both.any { !ownedByApp(it) }) {
                    val sender = try {
                        MediaStore.createDeleteRequest(context.contentResolver, both).intentSender
                    } catch (t: Throwable) {
                        null
                    }
                    if (sender == null) {
                        main.post { result.error("not_allowed", "cannot ask to delete", null) }
                    } else {
                        main.post { askUser(sender, item.uri, original, originalStays, result) }
                    }
                    return@execute
                }
                val outcome: String
                try {
                    outcome = deleteItem(item.uri)
                } catch (e: SecurityException) {
                    // The app does not own the item (any more): the system asks
                    // the user. Only this call, on an item that already passed
                    // [ownItem], may lead to a confirmation.
                    val sender = try {
                        userConfirmation(both, e)
                    } catch (t: Throwable) {
                        null
                    }
                    if (sender == null) {
                        main.post { result.error("not_allowed", e.message, null) }
                    } else {
                        main.post { askUser(sender, item.uri, original, originalStays, result) }
                    }
                    return@execute
                }
                // Never plain success when the original stays behind.
                val kept = originalStays || (original != null && !removed { deleteItem(original) })
                main.post { result.success(if (kept) KEPT_ORIGINAL else outcome) }
            } catch (e: FileNotFoundException) {
                main.post { result.success("gone") }
            } catch (e: NotOwnItemException) {
                main.post { result.error("not_allowed", e.message, null) }
            } catch (e: Throwable) {
                main.post { result.error("delete_failed", e.toString(), null) }
            }
        }
    }

    /** Whether the media item [uri] was written by this app (Android 10+); anything unknown is not. */
    private fun ownedByApp(uri: Uri): Boolean = try {
        OriginalRules.isOurs(
            context.contentResolver.query(
                uri,
                arrayOf(MediaStore.MediaColumns.OWNER_PACKAGE_NAME),
                null,
                null,
                null,
            )?.use { if (it.moveToFirst()) it.getString(0) else null },
            context.packageName,
        )
    } catch (e: Throwable) {
        false
    }

    /** Runs [block]; true when it worked, false when it threw (the item stays where it is). */
    private fun removed(block: () -> Unit): Boolean = try {
        block()
        true
    } catch (_: Throwable) {
        false
    }

    /**
     * The original saved with the developed photo at [photo], or null when the
     * option was off or it is not there. It is looked up by name in the
     * originals folder only, so nothing else can be reached through it.
     */
    private fun originalUriOf(photo: Uri): Uri? = try {
        val name = context.contentResolver.query(
            photo,
            arrayOf(MediaStore.MediaColumns.DISPLAY_NAME),
            null,
            null,
            null,
        )?.use { if (it.moveToFirst()) it.getString(0) else null }
        originalNameOf(name)?.let { findSaved(it, ORIGINALS_FOLDER) }?.let { Uri.parse(it) }
    } catch (e: Throwable) {
        null
    }

    /** The original that goes with the album file [photo] (Android 8-9), if it exists. */
    private fun originalFileOf(photo: File): File? {
        val name = originalNameOf(photo.name) ?: return null
        @Suppress("DEPRECATION")
        val file = File(
            File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES), ORIGINALS_FOLDER),
            "$name.jpg",
        )
        return if (file.isFile) file else null
    }

    /** The name of the original of the photo called [displayName] (a CARRETE_ name plus .jpg), or null. */
    private fun originalNameOf(displayName: String?): String? {
        val base = displayName?.removeSuffix(".jpg") ?: return null
        return if (base.matches(DEVELOPED_NAME)) "${base}_original" else null
    }

    /** Deletes the item: `deleted`, or `gone` when no row was there. */
    private fun deleteItem(uri: Uri): String =
        if (context.contentResolver.delete(uri, null, null) > 0) "deleted" else "gone"

    private fun deleteFile(file: File) {
        val path = file.absolutePath
        if (file.exists() && !file.delete()) throw java.io.IOException("could not delete $path")
        try {
            @Suppress("DEPRECATION")
            context.contentResolver.delete(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                "${MediaStore.Images.Media.DATA} = ?",
                arrayOf(path),
            )
        } catch (_: Throwable) {
            // The gallery row goes at the next scan.
        }
        MediaScannerConnection.scanFile(context, arrayOf(path), null, null)
    }

    /** The system dialog that lets the user allow deleting [uri], or null if there is none. */
    private fun userConfirmation(uris: List<Uri>, e: SecurityException): IntentSender? =
        when {
            // One dialog for the photo and its original.
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.R ->
                MediaStore.createDeleteRequest(context.contentResolver, uris).intentSender
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && e is RecoverableSecurityException ->
                e.userAction.actionIntent.intentSender
            else -> null
        }

    private fun askUser(
        sender: IntentSender,
        uri: Uri,
        original: Uri?,
        originalStays: Boolean,
        result: MethodChannel.Result,
    ) {
        val activity = activityProvider()
        if (activity == null || pendingDelete != null) {
            result.error("not_allowed", "no screen to ask on", null)
            return
        }
        pendingDelete = PendingDelete(
            uri,
            original,
            originalStays,
            result,
            retryAfterGrant = Build.VERSION.SDK_INT < Build.VERSION_CODES.R,
        )
        try {
            activity.startIntentSenderForResult(sender, DELETE_REQUEST, null, 0, 0, 0)
        } catch (e: Throwable) {
            pendingDelete = null
            result.error("delete_failed", e.toString(), null)
        }
    }

    /** Hands the answer of the system dialog over; false when the request is not ours. */
    fun onActivityResult(requestCode: Int, resultCode: Int): Boolean {
        if (requestCode != DELETE_REQUEST) return false
        val pending = pendingDelete ?: return true
        pendingDelete = null
        if (resultCode != Activity.RESULT_OK) {
            pending.result.success("cancelled")
            return true
        }
        if (!pending.retryAfterGrant) {
            // Android 11+: the request itself deleted the item (and its original, when ours).
            pending.result.success(if (pending.originalStays) KEPT_ORIGINAL else "deleted")
            return true
        }
        reader.execute {
            try {
                val outcome = deleteItem(pending.uri)
                // Never plain success when the original stays behind.
                val kept = pending.originalStays ||
                    (pending.original != null && !removed { deleteItem(pending.original) })
                main.post { pending.result.success(if (kept) KEPT_ORIGINAL else outcome) }
            } catch (e: Throwable) {
                main.post { pending.result.error("delete_failed", e.toString(), null) }
            }
        }
        return true
    }

    /**
     * The activity is going away (a new one will get a new channel): a delete
     * that waits for the system dialog is answered `cancelled`. If the user
     * confirms in the dialog anyway, the item goes and its row is cleared the
     * next time the gallery looks for missing photos.
     */
    fun dispose() {
        clearTiled()
        val pending = pendingDelete ?: return
        pendingDelete = null
        try {
            pending.result.success("cancelled")
        } catch (_: Throwable) {
            // The engine is already gone: nobody is waiting for the answer.
        }
    }

    /** Which of [locations] are certainly not in the media store any more. */
    private fun missingImages(locations: List<String>, result: MethodChannel.Result) {
        reader.execute {
            try {
                val missing = ArrayList<String>()
                val byId = HashMap<Long, MutableList<String>>()
                for (location in locations.take(MAX_MISSING_CHECK)) {
                    if (location.startsWith("content://")) {
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) continue
                        val uri = imageUriOf(location) ?: continue
                        byId.getOrPut(ContentUris.parseId(uri)) { ArrayList() }.add(location)
                    } else {
                        // Android 8-9 keep paths. A file is gone only when the storage
                        // is mounted and the album can be read: with the card out, or
                        // the folder unreadable, nothing is reported.
                        @Suppress("DEPRECATION")
                        val album = File(
                            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES),
                            "Diapo",
                        )
                        val file = try {
                            File(location).canonicalFile
                        } catch (e: Throwable) {
                            continue
                        }
                        if (file.parentFile != album.canonicalFile) continue
                        val mounted = Environment.getExternalStorageState() == Environment.MEDIA_MOUNTED
                        if (MissingRules.fileIsMissing(mounted, album.isDirectory && album.canRead(), file.exists())) {
                            missing.add(location)
                        }
                    }
                }
                val collection = MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                for (chunk in byId.keys.chunked(400)) {
                    val selection = MissingRules.idSelection(chunk)
                    val present = HashSet<Long>()
                    val cursor = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        // A photo in the system trash (or still pending) is not gone:
                        // the default query leaves those out.
                        context.contentResolver.query(
                            collection,
                            arrayOf(MediaStore.Images.Media._ID),
                            Bundle().apply {
                                putString(ContentResolver.QUERY_ARG_SQL_SELECTION, selection)
                                putInt(MediaStore.QUERY_ARG_MATCH_TRASHED, MediaStore.MATCH_INCLUDE)
                                putInt(MediaStore.QUERY_ARG_MATCH_PENDING, MediaStore.MATCH_INCLUDE)
                            },
                            null,
                        )
                    } else {
                        context.contentResolver.query(
                            collection,
                            arrayOf(MediaStore.Images.Media._ID),
                            selection,
                            null,
                            null,
                        )
                    }
                    // A query that fails says nothing: nothing is reported.
                    if (cursor == null) continue
                    cursor.use { while (it.moveToNext()) present.add(it.getLong(0)) }
                    for (id in chunk) if (id !in present) missing.addAll(byId[id]!!)
                }
                main.post { result.success(missing) }
            } catch (e: Throwable) {
                main.post { result.error("lookup_failed", e.toString(), null) }
            }
        }
    }
}

/** The album of the app and the subfolder of the untouched originals, under Pictures. */
private const val ALBUM_FOLDER = "Diapo"
private const val ORIGINALS_FOLDER = "Diapo/Originales"

/** Where the copy of an original waits in the cache before it is published (swept at start by Dart). */
private const val ORIGINAL_TEMP_FOLDER = "original-tmp"

/** The name of a developed photo, and of the original of one (the same plus `_original`). */
private val DEVELOPED_NAME = Regex("CARRETE_[A-Za-z0-9_]+")
private val ORIGINAL_NAME = Regex("CARRETE_[A-Za-z0-9_]+_original")

/** The answer of a delete that removed the photo but not its original. */
private const val KEPT_ORIGINAL = "deletedPhotoKeptOriginal"

/** The largest thumbnail side the viewer may ask for. */
private const val MAX_THUMBNAIL_EXTENT = 2048

/** The largest gallery item the viewer reads into memory (a 50 MP JPEG is well under). */
private const val MAX_IMAGE_BYTES = 64 * 1024 * 1024

/** The request code of the system dialog that confirms a delete. */
private const val DELETE_REQUEST = 4721

/** The most photos one `missingImages` call looks up. */
private const val MAX_MISSING_CHECK = 5000
