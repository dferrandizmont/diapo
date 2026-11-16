package io.github.dferrandizmont.carrete

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.os.Looper
import android.os.SystemClock
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Provider updates only while the foreground camera is active. Never starts a service. */
class LocationChannel(private val activity: Activity) {
    private val manager = activity.getSystemService(Context.LOCATION_SERVICE) as LocationManager
    private val prefs = activity.getSharedPreferences("location_permission", Context.MODE_PRIVATE)
    private val history = LocationPermissionHistory(prefs.getBoolean("denied", false))
    private var persistedDenied = history.denied
    private var permissionReply: MethodChannel.Result? = null
    private val listeners = mutableListOf<LocationListener>()
    private var best: LiveLocation? = null
    private var fixPermission: String? = null
    private var generation = 0
    private var foreground = false

    fun register(messenger: BinaryMessenger) {
        stop()
        MethodChannel(messenger, "carrete/location").setMethodCallHandler { call, result ->
            when (call.method) {
                "permission" -> result.success(permission())
                "requestPermission" -> requestPermission(result)
                "start" -> { start(); result.success(null) }
                "current" -> current(result)
                "stop" -> { stop(); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }

    private fun granted(name: String) = activity.checkSelfPermission(name) == PackageManager.PERMISSION_GRANTED

    fun permission(): String {
        val state = history.state(
            granted(Manifest.permission.ACCESS_FINE_LOCATION),
            granted(Manifest.permission.ACCESS_COARSE_LOCATION),
            activity.shouldShowRequestPermissionRationale(Manifest.permission.ACCESS_FINE_LOCATION) ||
                activity.shouldShowRequestPermissionRationale(Manifest.permission.ACCESS_COARSE_LOCATION),
        )
        if (history.denied != persistedDenied) {
            prefs.edit().putBoolean("denied", history.denied).apply()
            persistedDenied = history.denied
        }
        if (fixPermission != null && state != fixPermission) stop()
        return state
    }

    private fun requestPermission(result: MethodChannel.Result) {
        val state = permission()
        if (state == "granted" || state == "coarseOnly" || !foreground) {
            result.success(state)
            return
        }
        if (permissionReply != null) {
            result.error("permission_pending", "A location request is already pending", null)
            return
        }
        permissionReply = result
        activity.requestPermissions(arrayOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION,
        ), REQUEST_CODE)
    }

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != REQUEST_CODE) return false
        history.onResult(
            granted(Manifest.permission.ACCESS_FINE_LOCATION),
            granted(Manifest.permission.ACCESS_COARSE_LOCATION),
            completed = grantResults.isNotEmpty(),
        )
        permissionReply?.success(permission())
        permissionReply = null
        return true
    }

    @Suppress("MissingPermission", "DEPRECATION")
    private fun start() {
        val state = permission()
        if (!foreground || state !in listOf("granted", "coarseOnly")) {
            return
        }
        if (fixPermission == state) return
        fixPermission = state
        val currentGeneration = generation
        val providers = locationProviders(state == "granted")
            .filter { it in manager.allProviders }
        for (provider in providers) {
            if (generation != currentGeneration) break
            try {
                accept(manager.getLastKnownLocation(provider), currentGeneration)
                if (generation != currentGeneration) break
                val listener = object : LocationListener {
                    override fun onLocationChanged(location: Location) { accept(location, currentGeneration) }
                    override fun onProviderEnabled(provider: String) {}
                    override fun onProviderDisabled(provider: String) {}
                    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
                }
                manager.requestLocationUpdates(provider, UPDATE_INTERVAL_MILLIS, 0f, listener, Looper.getMainLooper())
                listeners.add(listener)
            } catch (_: SecurityException) {
                // Revoked permission: discard even a previously received fix.
                stop()
            } catch (_: IllegalArgumentException) {
                // A provider may disappear between the enabled check and request.
            }
        }
        if (listeners.isEmpty()) stop()
    }

    private fun accept(location: Location?, requestGeneration: Int) {
        if (!foreground || fixPermission == null || generation != requestGeneration ||
            location == null || !location.hasAccuracy()) return
        // Never relabel a fix acquired under a different permission level.
        if (permission() != fixPermission) { stop(); return }
        val candidate = PhotoLocation(
            location.latitude, location.longitude,
            if (location.hasAltitude()) location.altitude else null,
            location.accuracy.toDouble(), location.time, fixPermission == "coarseOnly",
        )
        best = LiveLocation.newestUsable(
            best, LiveLocation(candidate, location.elapsedRealtimeNanos), SystemClock.elapsedRealtimeNanos(),
        )
    }

    private fun current(result: MethodChannel.Result) {
        val state = permission()
        val location = best?.takeIf {
            foreground && state == fixPermission && it.isUsableAt(SystemClock.elapsedRealtimeNanos())
        }?.fix
        result.success(mapOf("permission" to state, "fix" to location?.let {
            mapOf(
                "latitude" to it.latitude, "longitude" to it.longitude,
                "altitude" to it.altitude,
                "accuracy" to it.accuracy, "time" to it.time,
                "approximate" to it.approximate,
            )
        }))
    }

    fun stop() {
        best = null
        fixPermission = null
        generation++
        listeners.forEach { try { manager.removeUpdates(it) } catch (_: SecurityException) {} }
        listeners.clear()
    }
    fun onPause() { foreground = false; stop() }
    fun onResume() { foreground = true }
    fun dispose() {
        foreground = false
        stop()
        permissionReply?.success("denied")
        permissionReply = null
    }

    companion object {
        const val REQUEST_CODE = 7042
        private const val UPDATE_INTERVAL_MILLIS = 5_000L
    }
}

/** Only a completed denial can imply permanent denial. A grant resets the
 * history so an expired one-time grant can be requested again. */
internal class LocationPermissionHistory(var denied: Boolean = false) {
    fun state(fine: Boolean, coarse: Boolean, rationale: Boolean): String {
        if (fine || coarse) denied = false
        return when {
            fine -> "granted"
            coarse -> "coarseOnly"
            denied && !rationale -> "permanentlyDenied"
            else -> "denied"
        }
    }

    fun onResult(fine: Boolean, coarse: Boolean, completed: Boolean) {
        if (fine || coarse) denied = false
        else if (completed) denied = true
    }
}

/** Older Android GPS providers require fine permission. With approximate
 * permission, still try the OS network provider instead of failing on GPS. */
internal fun locationProviders(fine: Boolean): List<String> = if (fine) {
    listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
} else {
    listOf(LocationManager.NETWORK_PROVIDER)
}
