package io.github.dferrandizmont.carrete

import androidx.exifinterface.media.ExifInterface
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ExifCopyTest {
    @Test
    fun `malformed shutter times save without GPS instead of using legacy validation`() {
        for (takenAt in listOf(null, "1794657645000", true, listOf(1), mapOf("time" to 1))) {
            val includeLocation = ExifCopy.allowsLocation(true, true, takenAt)
            assertFalse(includeLocation)
            val written = source.mapValues { it.value as String? }.toMutableMap()
            ExifCopy.copy(source::get, { tag, value -> written[tag] = value }, includeLocation)
            ExifCopy.writeLocation(includeLocation, fix) { tag, value -> written[tag] = value }
            assertEquals("Fixture", written[ExifInterface.TAG_MODEL])
            for (tag in ExifCopy.GPS_TAGS) assertNull(tag, written[tag])
        }
        assertTrue(ExifCopy.allowsLocation(true, false, null))
        assertTrue(ExifCopy.allowsLocation(true, true, fix.time))
        assertFalse(ExifCopy.allowsLocation(false, true, fix.time))
    }

    private val source = mapOf(
        ExifInterface.TAG_MAKE to "Carrete Test",
        ExifInterface.TAG_MODEL to "Fixture",
        ExifInterface.TAG_EXPOSURE_TIME to "0.01",
        ExifInterface.TAG_GPS_LATITUDE to "40/1,25/1,0/1",
        ExifInterface.TAG_GPS_LATITUDE_REF to "N",
        ExifInterface.TAG_GPS_LONGITUDE to "3/1,42/1,0/1",
        ExifInterface.TAG_GPS_LONGITUDE_REF to "W",
        ExifInterface.TAG_GPS_ALTITUDE to "650/1",
        ExifInterface.TAG_GPS_TIMESTAMP to "12:00:00",
        ExifInterface.TAG_GPS_DATESTAMP to "2026:11:09",
        ExifInterface.TAG_GPS_PROCESSING_METHOD to "GPS",
    )

    @Test
    fun `the camera tags and the GPS tags are disjoint`() {
        val shared = ExifCopy.BASE_TAGS.intersect(ExifCopy.GPS_TAGS.toSet())
        assertTrue("shared tags: $shared", shared.isEmpty())
        assertTrue(ExifCopy.BASE_TAGS.none { it.startsWith("GPS") })
        assertTrue(ExifCopy.GPS_TAGS.all { it.startsWith("GPS") })
    }

    @Test
    fun `without location no GPS value is written and every GPS tag is nulled`() {
        val written = mutableMapOf<String, String?>()
        ExifCopy.copy(source::get, { tag, value -> written[tag] = value }, includeLocation = false)

        assertEquals("Carrete Test", written[ExifInterface.TAG_MAKE])
        assertEquals("0.01", written[ExifInterface.TAG_EXPOSURE_TIME])
        for (tag in ExifCopy.GPS_TAGS) {
            assertTrue("$tag not written", written.containsKey(tag))
            assertNull("$tag carried a value", written[tag])
        }
        assertFalse(written.values.any { it != null && it in setOf("40/1,25/1,0/1", "N", "3/1,42/1,0/1", "W") })
    }

    @Test
    fun `clearing the GPS of an original writes null to every GPS tag and nothing else`() {
        val written = mutableListOf<String>()
        ExifCopy.clearGps { tag -> written.add(tag) }
        assertEquals(ExifCopy.GPS_TAGS, written)
    }

    @Test
    fun `with location the GPS tags of the source are copied`() {
        val written = mutableMapOf<String, String?>()
        ExifCopy.copy(source::get, { tag, value -> written[tag] = value }, includeLocation = true)

        assertEquals("40/1,25/1,0/1", written[ExifInterface.TAG_GPS_LATITUDE])
        assertEquals("W", written[ExifInterface.TAG_GPS_LONGITUDE_REF])
        assertEquals("2026:11:09", written[ExifInterface.TAG_GPS_DATESTAMP])
        // Tags the source does not have are not touched.
        assertFalse(written.containsKey(ExifInterface.TAG_GPS_SPEED))
    }

    @Test
    fun `a source with every GPS tag set leaks none of them`() {
        val everything = ExifCopy.GPS_TAGS.associateWith { "value of $it" } +
            mapOf(ExifInterface.TAG_MODEL to "Fixture")
        val written = mutableMapOf<String, String?>()
        ExifCopy.copy(everything::get, { tag, value -> written[tag] = value }, includeLocation = false)

        assertEquals("Fixture", written[ExifInterface.TAG_MODEL])
        assertTrue(written.values.none { it != null && it.startsWith("value of GPS") })
        assertEquals(ExifCopy.GPS_TAGS.size + 1, written.size)
    }

    private val fix = PhotoLocation(-40.5, -3.25, -12.5, 8.25, 1_794_657_645_000L)

    @Test
    fun `writer validates fields even in legacy snapshots without a shutter`() {
        for (invalid in listOf(
            fix.copy(latitude = 91.0), fix.copy(longitude = Double.NaN),
            fix.copy(accuracy = 100.0), fix.copy(altitude = Double.POSITIVE_INFINITY),
            fix.copy(time = 0),
        )) {
            val written = source.mapValues { it.value as String? }.toMutableMap()
            ExifCopy.writeLocation(true, invalid) { tag, value -> written[tag] = value }
            for (tag in ExifCopy.GPS_TAGS) assertNull(tag, written[tag])
        }
    }

    @Test
    fun `a shutter location replaces all source GPS tags with standard EXIF`() {
        val written = source.mapValues { it.value as String? }.toMutableMap()
        ExifCopy.writeLocation(true, fix) { tag, value -> written[tag] = value }
        assertEquals("40/1,30/1,0/1000000", written[ExifInterface.TAG_GPS_LATITUDE])
        assertEquals("S", written[ExifInterface.TAG_GPS_LATITUDE_REF])
        assertEquals("3/1,15/1,0/1000000", written[ExifInterface.TAG_GPS_LONGITUDE])
        assertEquals("W", written[ExifInterface.TAG_GPS_LONGITUDE_REF])
        assertEquals("12500/1000", written[ExifInterface.TAG_GPS_ALTITUDE])
        assertEquals("1", written[ExifInterface.TAG_GPS_ALTITUDE_REF])
        assertEquals("8250/1000", written[ExifInterface.TAG_GPS_H_POSITIONING_ERROR])
        assertEquals("2026:11:14", written[ExifInterface.TAG_GPS_DATESTAMP])
        assertEquals("12:00:45", written[ExifInterface.TAG_GPS_TIMESTAMP])
        assertNull(written[ExifInterface.TAG_GPS_PROCESSING_METHOD])
        assertEquals("Fixture", written[ExifInterface.TAG_MODEL])
    }

    @Test
    fun `high altitudes fit the unsigned 32 bit EXIF rational`() {
        val written = mutableMapOf<String, String?>()
        ExifCopy.writeLocation(true, fix.copy(altitude = 8848.86)) { tag, value -> written[tag] = value }
        assertEquals("8848860/1000", written[ExifInterface.TAG_GPS_ALTITUDE])
        assertEquals("0", written[ExifInterface.TAG_GPS_ALTITUDE_REF])
    }

    @Test
    fun `an absent altitude never keeps the source altitude`() {
        val written = mutableMapOf<String, String?>()
        ExifCopy.writeLocation(true, fix.copy(altitude = null)) { tag, value -> written[tag] = value }
        assertNull(written[ExifInterface.TAG_GPS_ALTITUDE])
        assertNull(written[ExifInterface.TAG_GPS_ALTITUDE_REF])
    }

    @Test
    fun `off is exactly the existing GPS clear operation even with a fix`() {
        val expected = mutableMapOf<String, String?>()
        ExifCopy.clearGps { expected[it] = null }
        for (location in listOf(null, fix)) {
            val written = mutableMapOf<String, String?>()
            ExifCopy.writeLocation(false, location) { tag, value -> written[tag] = value }
            assertEquals(expected, written)
        }
    }

    @Test
    fun `imports without a device fix leave their opted in source GPS untouched`() {
        val written = source.mapValues { it.value as String? }.toMutableMap()
        ExifCopy.writeLocation(true, null) { tag, value -> written[tag] = value }
        assertEquals(source, written)
    }

}
