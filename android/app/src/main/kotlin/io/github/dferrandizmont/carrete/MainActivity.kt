package io.github.dferrandizmont.carrete

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.net.Uri
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var media: MediaChannel? = null
    private var sounds: CameraSounds? = null
    private var settingsDocuments: SettingsBackupDocuments? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        settingsDocuments?.restoreState(savedInstanceState)
    }

    override fun onSaveInstanceState(outState: Bundle) {
        settingsDocuments?.saveState(outState)
        super.onSaveInstanceState(outState)
    }

    private var location: LocationChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        location = LocationChannel(this).also { it.register(flutterEngine.dartExecutor.binaryMessenger) }
        media = MediaChannel(applicationContext) { this }.also {
            it.register(flutterEngine.dartExecutor.binaryMessenger)
        }
        val cameraSounds = CameraSounds(applicationContext).also { sounds = it }
        val documents = SettingsBackupDocuments(this).also { settingsDocuments = it }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "carrete/system")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "exportSettings", "importSettings" -> documents.handle(call, result)
                    "openAppSettings" -> result.success(openAppSettings())
                    "openKofi" -> result.success(openKofi())
                    "cameraPermission" -> result.success(
                        ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) ==
                            PackageManager.PERMISSION_GRANTED,
                    )
                    "ringerMode" -> result.success(cameraSounds.ringerMode())
                    // Answers once the sounds are decoded (or after a timeout).
                    "loadSounds" -> cameraSounds.load { ok -> result.success(ok) }
                    "playSound" -> {
                        val name = call.argument<String>("name")
                        result.success(name != null && cameraSounds.play(name))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        // A delete that waits for the system dialog cannot be answered after this.
        location?.dispose()
        location = null
        media?.dispose()
        media = null
        sounds?.release()
        sounds = null
        settingsDocuments?.dispose()
        settingsDocuments = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (settingsDocuments?.onActivityResult(requestCode, resultCode, data) == true) return
        // The confirmation Android asks before deleting a photo the app no longer owns.
        if (media?.onActivityResult(requestCode, resultCode) == true) return
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onPause() {
        location?.onPause()
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        location?.onResume()
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        if (location?.onRequestPermissionsResult(requestCode, grantResults) == true) return
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    /**
     * Opens the Ko-fi page of the developer in the system browser (the app has
     * no internet permission; the browser does the loading). The address is a
     * constant here, so the channel cannot be asked to open anything else.
     */
    private fun openKofi(): Boolean {
        return try {
            startActivity(
                Intent(Intent.ACTION_VIEW, Uri.parse(KOFI_URL))
                    .addCategory(Intent.CATEGORY_BROWSABLE)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
            true
        } catch (e: ActivityNotFoundException) {
            false
        }
    }

    /** Opens the system page of this app (permissions, storage...). */
    private fun openAppSettings(): Boolean {
        return try {
            startActivity(
                Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.fromParts("package", packageName, null),
                ),
            )
            true
        } catch (e: Exception) {
            false
        }
    }

    private companion object {
        const val KOFI_URL = "https://ko-fi.com/danielmfdev"
    }
}
