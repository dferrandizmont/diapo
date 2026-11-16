package io.github.dferrandizmont.carrete

import androidx.exifinterface.media.ExifInterface
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import kotlin.math.abs
import kotlin.math.roundToLong

/**
 * Which EXIF tags travel from the camera original to the saved photo.
 *
 * The camera tags ([BASE_TAGS]) always do. The GPS tags ([GPS_TAGS]) only do
 * when the user turned the location on; otherwise every one of them is set to
 * null explicitly, so a source with GPS (an imported photo, one day) never
 * leaks it. Pure logic over a reader and a writer, so a JVM test can check it
 * without Android.
 */
object ExifCopy {
    /** Missing shutter times are legacy metadata; malformed ones disable GPS. */
    fun allowsLocation(includeLocation: Boolean, hasTakenAt: Boolean, takenAt: Any?): Boolean =
        includeLocation && (!hasTakenAt || takenAt is Number)

    /** Replaces source GPS with the shutter fix; off always follows the same
     * null-every-tag path, even if a caller supplies a location accidentally.
     * Validate freshness against the shutter when supplied. Legacy snapshots
     * without a shutter retain field validation only. */
    fun writeLocation(
        includeLocation: Boolean,
        location: PhotoLocation?,
        takenAt: Long? = null,
        write: (String, String?) -> Unit,
    ) {
        if (!includeLocation) { clearGps { write(it, null) }; return }
        if (location == null) return // Imports preserve the source's GPS.
        clearGps { write(it, null) }
        if (!location.hasValidFields() || (takenAt != null && !location.isUsableAt(takenAt))) return
        fun rational(value: Double, scale: Long = 1_000_000) = "${(abs(value) * scale).roundToLong()}/$scale"
        fun coordinate(value: Double): String {
            val degrees = abs(value).toInt()
            val minutes = ((abs(value) - degrees) * 60).toInt()
            val seconds = ((abs(value) - degrees) * 60 - minutes) * 60
            return "$degrees/1,$minutes/1,${rational(seconds)}"
        }
        write(ExifInterface.TAG_GPS_VERSION_ID, "2.3.0.0")
        write(ExifInterface.TAG_GPS_LATITUDE, coordinate(location.latitude))
        write(ExifInterface.TAG_GPS_LATITUDE_REF, if (location.latitude < 0) "S" else "N")
        write(ExifInterface.TAG_GPS_LONGITUDE, coordinate(location.longitude))
        write(ExifInterface.TAG_GPS_LONGITUDE_REF, if (location.longitude < 0) "W" else "E")
        location.altitude?.let {
            // Millimetres keep even mountain altitudes inside EXIF uint32 rationals.
            write(ExifInterface.TAG_GPS_ALTITUDE, rational(it, 1_000))
            write(ExifInterface.TAG_GPS_ALTITUDE_REF, if (it < 0) "1" else "0")
        }
        // Millimetres also keep coarse accuracy inside EXIF uint32 rationals.
        write(ExifInterface.TAG_GPS_H_POSITIONING_ERROR, rational(location.accuracy, 1_000))
        write(ExifInterface.TAG_GPS_MAP_DATUM, "WGS-84")
        val date = Date(location.time)
        fun utc(pattern: String) = SimpleDateFormat(pattern, Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }.format(date)
        write(ExifInterface.TAG_GPS_DATESTAMP, utc("yyyy:MM:dd"))
        write(ExifInterface.TAG_GPS_TIMESTAMP, utc("HH:mm:ss"))
    }

    /** The camera tags: time, lens, exposure. Never a location. */
    val BASE_TAGS: List<String> = listOf(
        ExifInterface.TAG_DATETIME,
        ExifInterface.TAG_DATETIME_ORIGINAL,
        ExifInterface.TAG_DATETIME_DIGITIZED,
        ExifInterface.TAG_OFFSET_TIME,
        ExifInterface.TAG_OFFSET_TIME_ORIGINAL,
        ExifInterface.TAG_SUBSEC_TIME_ORIGINAL,
        ExifInterface.TAG_MAKE,
        ExifInterface.TAG_MODEL,
        ExifInterface.TAG_F_NUMBER,
        ExifInterface.TAG_EXPOSURE_TIME,
        ExifInterface.TAG_PHOTOGRAPHIC_SENSITIVITY,
        ExifInterface.TAG_FOCAL_LENGTH,
        ExifInterface.TAG_FOCAL_LENGTH_IN_35MM_FILM,
        ExifInterface.TAG_APERTURE_VALUE,
        ExifInterface.TAG_WHITE_BALANCE,
        ExifInterface.TAG_FLASH,
    )

    /** Every GPS tag ExifInterface knows. Copied only on request, nulled otherwise. */
    val GPS_TAGS: List<String> = listOf(
        ExifInterface.TAG_GPS_VERSION_ID,
        ExifInterface.TAG_GPS_LATITUDE_REF,
        ExifInterface.TAG_GPS_LATITUDE,
        ExifInterface.TAG_GPS_LONGITUDE_REF,
        ExifInterface.TAG_GPS_LONGITUDE,
        ExifInterface.TAG_GPS_ALTITUDE_REF,
        ExifInterface.TAG_GPS_ALTITUDE,
        ExifInterface.TAG_GPS_TIMESTAMP,
        ExifInterface.TAG_GPS_SATELLITES,
        ExifInterface.TAG_GPS_STATUS,
        ExifInterface.TAG_GPS_MEASURE_MODE,
        ExifInterface.TAG_GPS_DOP,
        ExifInterface.TAG_GPS_SPEED_REF,
        ExifInterface.TAG_GPS_SPEED,
        ExifInterface.TAG_GPS_TRACK_REF,
        ExifInterface.TAG_GPS_TRACK,
        ExifInterface.TAG_GPS_IMG_DIRECTION_REF,
        ExifInterface.TAG_GPS_IMG_DIRECTION,
        ExifInterface.TAG_GPS_MAP_DATUM,
        ExifInterface.TAG_GPS_DEST_LATITUDE_REF,
        ExifInterface.TAG_GPS_DEST_LATITUDE,
        ExifInterface.TAG_GPS_DEST_LONGITUDE_REF,
        ExifInterface.TAG_GPS_DEST_LONGITUDE,
        ExifInterface.TAG_GPS_DEST_BEARING_REF,
        ExifInterface.TAG_GPS_DEST_BEARING,
        ExifInterface.TAG_GPS_DEST_DISTANCE_REF,
        ExifInterface.TAG_GPS_DEST_DISTANCE,
        ExifInterface.TAG_GPS_PROCESSING_METHOD,
        ExifInterface.TAG_GPS_AREA_INFORMATION,
        ExifInterface.TAG_GPS_DATESTAMP,
        ExifInterface.TAG_GPS_DIFFERENTIAL,
        ExifInterface.TAG_GPS_H_POSITIONING_ERROR,
    )

    /**
     * Writes null to every GPS tag: what the copy of an untouched original
     * goes through when the location is off.
     */
    fun clearGps(write: (String) -> Unit) {
        for (tag in GPS_TAGS) write(tag)
    }

    /**
     * Copies the tags from [read] to [write]. With [includeLocation] false the
     * GPS tags are not read at all and each is written as null.
     */
    fun copy(
        read: (String) -> String?,
        write: (String, String?) -> Unit,
        includeLocation: Boolean,
    ) {
        for (tag in BASE_TAGS) {
            read(tag)?.let { write(tag, it) }
        }
        if (includeLocation) {
            for (tag in GPS_TAGS) {
                read(tag)?.let { write(tag, it) }
            }
        } else {
            for (tag in GPS_TAGS) {
                write(tag, null)
            }
        }
    }

    /** [copy] between two [ExifInterface]s. The caller saves [dst]. */
    fun copy(src: ExifInterface, dst: ExifInterface, includeLocation: Boolean) =
        copy(src::getAttribute, dst::setAttribute, includeLocation)
}
