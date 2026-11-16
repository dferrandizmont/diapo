package io.github.dferrandizmont.carrete

/** A shutter snapshot; freshness is checked against capture time, never development time. */
data class PhotoLocation(
    val latitude: Double,
    val longitude: Double,
    val altitude: Double?,
    val accuracy: Double,
    val time: Long,
    val approximate: Boolean = false,
) {
    internal fun hasValidFields(): Boolean =
        latitude.isFinite() && latitude in -90.0..90.0 &&
            longitude.isFinite() && longitude in -180.0..180.0 &&
            acceptsAccuracy(accuracy, approximate) && time > 0 &&
            (altitude == null || (altitude.isFinite() && altitude in -1000.0..100000.0))

    /** Use the shutter time for snapshots, never the later development time. */
    fun isUsableAt(shutter: Long): Boolean = hasValidFields() &&
        shutter >= time && shutter - time <=
            if (approximate) APPROXIMATE_MAX_FIX_AGE_MILLIS else PRECISE_MAX_FIX_AGE_MILLIS

    companion object {
        const val PRECISE_ACCURACY_LIMIT_METERS = 100.0
        const val APPROXIMATE_ACCURACY_LIMIT_METERS = 5000.0
        const val PRECISE_MAX_FIX_AGE_MILLIS = 120_000L
        const val APPROXIMATE_MAX_FIX_AGE_MILLIS = 600_000L

        /** Freshness wins over accuracy, provided the candidate is usable. */
        fun newestUsable(previous: PhotoLocation?, candidate: PhotoLocation?, now: Long): PhotoLocation? {
            val held = previous?.takeIf { it.isUsableAt(now) }
            val next = candidate?.takeIf { it.isUsableAt(now) } ?: return held
            return if (held == null || next.time > held.time ||
                (next.time == held.time && next.accuracy < held.accuracy)) next else held
        }

        fun acceptsAccuracy(accuracy: Double, approximate: Boolean): Boolean =
            accuracy.isFinite() && accuracy >= 0 && if (approximate) {
                accuracy <= APPROXIMATE_ACCURACY_LIMIT_METERS
            } else {
                accuracy < PRECISE_ACCURACY_LIMIT_METERS
            }

        fun from(value: Map<*, *>?): PhotoLocation? {
            if (value == null) return null
            val lat = (value["latitude"] as? Number)?.toDouble() ?: return null
            val lon = (value["longitude"] as? Number)?.toDouble() ?: return null
            val accuracy = (value["accuracy"] as? Number)?.toDouble() ?: return null
            val time = (value["time"] as? Number)?.toLong() ?: return null
            val altitude = (value["altitude"] as? Number)?.toDouble()
            val approximateValue = value["approximate"]
            if (approximateValue != null && approximateValue !is Boolean) return null
            val approximate = approximateValue == true
            // Persisted shutter snapshots can be developed days later. Only the
            // live acquisition and shutter checks apply an age limit.
            return PhotoLocation(lat, lon, altitude, accuracy, time, approximate)
                .takeIf { it.hasValidFields() }
        }
    }
}

/** Native acquisition uses the boot clock; wall time is retained only for metadata. */
internal data class LiveLocation(val fix: PhotoLocation, val elapsedRealtimeNanos: Long) {
    fun isUsableAt(nowNanos: Long): Boolean = fix.hasValidFields() &&
        elapsedRealtimeNanos >= 0 && nowNanos >= elapsedRealtimeNanos &&
        nowNanos - elapsedRealtimeNanos <= (if (fix.approximate) {
            PhotoLocation.APPROXIMATE_MAX_FIX_AGE_MILLIS
        } else {
            PhotoLocation.PRECISE_MAX_FIX_AGE_MILLIS
        }) * 1_000_000L

    companion object {
        fun newestUsable(previous: LiveLocation?, candidate: LiveLocation, nowNanos: Long): LiveLocation? {
            val held = previous?.takeIf { it.isUsableAt(nowNanos) }
            if (!candidate.isUsableAt(nowNanos)) return held
            return if (held == null || candidate.elapsedRealtimeNanos > held.elapsedRealtimeNanos ||
                (candidate.elapsedRealtimeNanos == held.elapsedRealtimeNanos && candidate.fix.accuracy < held.fix.accuracy)) {
                candidate
            } else held
        }
    }
}
