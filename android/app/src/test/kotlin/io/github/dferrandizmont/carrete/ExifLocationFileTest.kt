package io.github.dferrandizmont.carrete

import androidx.exifinterface.media.ExifInterface
import java.io.File
import java.util.TimeZone
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.assertFalse
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

/** The real AndroidX JPEG parser and writer run against a real JPEG on disk. */
class ExifLocationFileTest {
    @get:Rule val temporary = TemporaryFolder()

    private fun jpeg(): File = temporary.newFile("photo.jpg").also {
        requireNotNull(javaClass.getResourceAsStream("/location_fixture.jpg")).use { input ->
            it.writeBytes(input.readBytes())
        }
    }

    @Test fun `GPS survives a real JPEG save and read in UTC`() {
        val previous = TimeZone.getDefault()
        TimeZone.setDefault(TimeZone.getTimeZone("GMT+09:00"))
        try {
            val file = jpeg()
            for (fix in listOf(
                PhotoLocation(-40.512345, -3.251234, -12.5, 8.25, 1_794_657_645_000L),
                PhotoLocation(40.512345, 3.251234, 8848.86, 8.25, 1_794_657_645_000L),
            )) {
                val exif = ExifInterface(file)
                ExifCopy.writeLocation(true, fix, write = exif::setAttribute)
                exif.saveAttributes()
                val read = ExifInterface(file)
                val coordinates = requireNotNull(read.latLong)
                assertEquals(fix.latitude, coordinates[0], 0.000001)
                assertEquals(fix.longitude, coordinates[1], 0.000001)
                assertEquals(if (fix.latitude < 0) "S" else "N", read.getAttribute(ExifInterface.TAG_GPS_LATITUDE_REF))
                assertEquals(if (fix.longitude < 0) "W" else "E", read.getAttribute(ExifInterface.TAG_GPS_LONGITUDE_REF))
                assertEquals(fix.altitude!!, read.getAltitude(Double.NaN), 0.001)
                assertEquals(if (fix.altitude < 0) "1" else "0", read.getAttribute(ExifInterface.TAG_GPS_ALTITUDE_REF))
                assertEquals("2026:11:14", read.getAttribute(ExifInterface.TAG_GPS_DATESTAMP))
                assertEquals("12:00:45", read.getAttribute(ExifInterface.TAG_GPS_TIMESTAMP))
                assertEquals(fix.time, read.gpsDateTime)
            }
        } finally {
            TimeZone.setDefault(previous)
        }
    }

    @Test fun `switch off removes every GPS tag from a real JPEG even with a fix`() {
        val file = jpeg()
        val fix = PhotoLocation(40.5, -3.25, -12.5, 8.25, 1_794_657_645_000L)
        for (location in listOf(fix, null)) {
            ExifInterface(file).apply {
                ExifCopy.writeLocation(true, fix, write = this::setAttribute)
                saveAttributes()
            }
            ExifInterface(file).apply {
                ExifCopy.writeLocation(false, location, write = this::setAttribute)
                saveAttributes()
            }
            val read = ExifInterface(file)
            for (tag in ExifCopy.GPS_TAGS) assertNull(tag, read.getAttribute(tag))
            assertNull(read.latLong)
            assertNull(read.gpsDateTime)
        }
    }

    @Test fun `approximate fix writes its real accuracy to the JPEG`() {
        val file = jpeg()
        for (accuracy in listOf(2000.0, 5000.0)) {
            val fix = requireNotNull(PhotoLocation.from(mapOf(
                "latitude" to 40.5, "longitude" to -3.25, "accuracy" to accuracy,
                "time" to 1_794_657_645_000L, "approximate" to true,
            )))
            ExifInterface(file).apply {
                ExifCopy.writeLocation(true, fix, write = this::setAttribute)
                saveAttributes()
            }
            val read = ExifInterface(file)
            assertEquals(accuracy, read.getAttributeDouble(ExifInterface.TAG_GPS_H_POSITIONING_ERROR, -1.0), 0.001)
            assertNull(read.getAttribute(ExifInterface.TAG_GPS_DOP))
        }
    }

    @Test fun `a shutter snapshot still writes GPS when its roll is developed days later`() {
        val fixTime = 1_794_657_645_000L
        val shutter = fixTime + 480_000L
        val developed = shutter + 3 * 86_400_000L
        val fix = requireNotNull(PhotoLocation.from(mapOf(
            "latitude" to 40.5, "longitude" to -3.25, "accuracy" to 2000.0,
            "time" to fixTime, "approximate" to true,
        )))
        assertTrue(fix.isUsableAt(shutter))
        assertFalse(fix.isUsableAt(developed))
        val file = jpeg()
        ExifInterface(file).apply {
            ExifCopy.writeLocation(true, fix, takenAt = shutter, write = this::setAttribute)
            saveAttributes()
        }
        val read = ExifInterface(file)
        assertEquals(fixTime, read.gpsDateTime)
        assertEquals(40.5, requireNotNull(read.latLong)[0], 0.000001)
    }

    @Test fun `writer rejects stale or future shutter fixes and clears source GPS`() {
        val file = jpeg()
        val precise = PhotoLocation(40.5, -3.25, 650.0, 10.0, 1_794_657_645_000L)
        for ((fix, maxAge) in listOf(
            precise to 120_000L,
            precise.copy(approximate = true, accuracy = 2000.0) to 600_000L,
        )) {
            for (age in listOf(-1L, maxAge + 1)) {
                ExifInterface(file).apply {
                    ExifCopy.writeLocation(true, precise, write = this::setAttribute)
                    saveAttributes()
                }
                ExifInterface(file).apply {
                    ExifCopy.writeLocation(true, fix, takenAt = fix.time + age, write = this::setAttribute)
                    saveAttributes()
                }
                val read = ExifInterface(file)
                for (tag in ExifCopy.GPS_TAGS) assertNull(tag, read.getAttribute(tag))
                assertNull(read.latLong)
                assertNull(read.gpsDateTime)
            }
        }
    }

    @Test fun `writer accepts freshness boundaries and legacy payloads without a shutter`() {
        val file = jpeg()
        val precise = PhotoLocation(40.5, -3.25, 650.0, 10.0, 1_794_657_645_000L)
        for ((fix, maxAge) in listOf(
            precise to 120_000L,
            precise.copy(approximate = true, accuracy = 5000.0) to 600_000L,
        )) {
            for (shutter in listOf(null, fix.time, fix.time + maxAge)) {
                ExifInterface(file).apply {
                    ExifCopy.writeLocation(true, fix, takenAt = shutter, write = this::setAttribute)
                    saveAttributes()
                }
                val read = ExifInterface(file)
                assertEquals(fix.time, read.gpsDateTime)
                assertEquals(fix.latitude, requireNotNull(read.latLong)[0], 0.000001)
            }
        }
    }
}
