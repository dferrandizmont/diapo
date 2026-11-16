package io.github.dferrandizmont.carrete

import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.assertSame
import org.junit.Test

class PhotoLocationTest {
    private val valid = mapOf("latitude" to 40.0, "longitude" to -3.0,
        "altitude" to 650.0, "accuracy" to 10.0, "time" to 1_794_657_645_000L)

    @Test fun `live freshness uses nanosecond age for both permission levels`() {
        val bootTime = 1_000_000_000_000L
        val precise = requireNotNull(PhotoLocation.from(valid))
        for ((fix, maxAge) in listOf(
            precise to 120_000_000_000L,
            precise.copy(approximate = true, accuracy = 2000.0) to 600_000_000_000L,
        )) {
            val live = LiveLocation(fix, bootTime)
            assertTrue(live.isUsableAt(bootTime))
            assertTrue(live.isUsableAt(bootTime + maxAge))
            assertFalse(live.isUsableAt(bootTime + maxAge + 1))
            assertFalse(live.isUsableAt(bootTime - 1))
            assertFalse(LiveLocation(fix, -1).isUsableAt(bootTime))
            assertFalse(LiveLocation(fix.copy(accuracy = Double.NaN), bootTime).isUsableAt(bootTime))
        }
    }

    @Test fun `wall clock changes cannot refresh old fixes or reverse acquisition order`() {
        val fix = requireNotNull(PhotoLocation.from(valid))
        val bootTime = 1_000_000_000_000L
        val old = LiveLocation(fix, bootTime)
        // The wall clock moves back an hour between acquisitions.
        val newer = LiveLocation(fix.copy(time = fix.time - 3_600_000L, accuracy = 80.0), bootTime + 5_000_000_000L)
        assertSame(newer, LiveLocation.newestUsable(old, newer, newer.elapsedRealtimeNanos))
        assertSame(newer, LiveLocation.newestUsable(newer, old, newer.elapsedRealtimeNanos))
        val accurate = newer.copy(fix = newer.fix.copy(accuracy = 5.0))
        assertSame(accurate, LiveLocation.newestUsable(newer, accurate, newer.elapsedRealtimeNanos))
        // A cached fix dated in the wall-clock future still expires by boot age.
        val futureWallTime = LiveLocation(fix.copy(time = fix.time + 86_400_000L), bootTime)
        assertTrue(futureWallTime.isUsableAt(bootTime + 120_000_000_000L))
        assertFalse(futureWallTime.isUsableAt(bootTime + 120_000_000_001L))
        assertNull(LiveLocation.newestUsable(old, futureWallTime, bootTime + 180_000_000_000L))
    }

    @Test fun `precise freshness includes two minutes and rejects three minutes and future fixes`() {
        val fix = requireNotNull(PhotoLocation.from(valid))
        assertTrue(fix.isUsableAt(fix.time))
        assertTrue(fix.isUsableAt(fix.time + 120_000L))
        assertFalse(fix.isUsableAt(fix.time + 120_001L))
        assertFalse(fix.isUsableAt(fix.time + 180_000L))
        assertFalse(fix.isUsableAt(fix.time - 1))
    }

    @Test fun `approximate freshness includes eight and ten minutes but rejects eleven`() {
        val fix = requireNotNull(PhotoLocation.from(valid + mapOf("approximate" to true, "accuracy" to 5000.0)))
        assertTrue(fix.isUsableAt(fix.time + 480_000L))
        assertTrue(fix.isUsableAt(fix.time + 600_000L))
        assertFalse(fix.isUsableAt(fix.time + 600_001L))
        assertFalse(fix.isUsableAt(fix.time + 660_000L))
        assertFalse(fix.isUsableAt(fix.time - 1))
    }

    @Test fun `newest usable fix wins even with worse accuracy`() {
        val older = requireNotNull(PhotoLocation.from(valid))
        val newer = older.copy(time = older.time + 5000, accuracy = 80.0)
        assertSame(newer, PhotoLocation.newestUsable(older, newer, newer.time))
        assertSame(newer, PhotoLocation.newestUsable(newer, older, newer.time))
        val moreAccurate = newer.copy(accuracy = 5.0)
        assertSame(moreAccurate, PhotoLocation.newestUsable(newer, moreAccurate, newer.time))
        assertSame(older, PhotoLocation.newestUsable(null, older, older.time))
    }

    @Test fun `unusable candidates never replace usable fixes and expired held fixes are dropped`() {
        val fix = requireNotNull(PhotoLocation.from(valid))
        for (candidate in listOf(null, fix.copy(time = fix.time + 1),
            fix.copy(accuracy = 100.0), fix.copy(latitude = 91.0),
            fix.copy(time = fix.time - 180_000L))) {
            assertSame(fix, PhotoLocation.newestUsable(fix, candidate, fix.time))
        }
        assertNull(PhotoLocation.newestUsable(fix, null, fix.time + 180_000L))
        assertNull(PhotoLocation.newestUsable(null, fix.copy(approximate = true), fix.time + 660_000L))
    }

    @Test fun `legacy and explicit precise fixes keep the strict accuracy limit`() {
        for (json in listOf(valid, valid + ("approximate" to false))) {
            assertFalse(requireNotNull(PhotoLocation.from(json)).approximate)
            assertNotNull(PhotoLocation.from(json + ("accuracy" to 99.99)))
            for (accuracy in listOf(100.0, 2000.0, 5000.0)) {
                assertNull(PhotoLocation.from(json + ("accuracy" to accuracy)))
                assertFalse(PhotoLocation.acceptsAccuracy(accuracy, false))
            }
        }
    }

    @Test fun `approximate fixes accept up to 5000 metres without changing accuracy`() {
        val json = valid + ("approximate" to true)
        for (accuracy in listOf(0.0, 100.0, 2000.0, 5000.0)) {
            val fix = requireNotNull(PhotoLocation.from(json + ("accuracy" to accuracy)))
            assertTrue(fix.approximate)
            assertEquals(accuracy, fix.accuracy, 0.0)
            assertTrue(PhotoLocation.acceptsAccuracy(accuracy, true))
        }
        for (accuracy in listOf(-1.0, 5000.01, Double.NaN, Double.POSITIVE_INFINITY)) {
            assertNull(PhotoLocation.from(json + ("accuracy" to accuracy)))
            assertFalse(PhotoLocation.acceptsAccuracy(accuracy, true))
        }
        assertNull(PhotoLocation.from(valid + ("approximate" to "true")))
    }

    @Test fun `timestamps must be positive`() {
        for (time in listOf(0L, -1L, Long.MIN_VALUE)) {
            assertNull(PhotoLocation.from(valid + ("time" to time)))
        }
        assertNotNull(PhotoLocation.from(valid + ("time" to 1L)))
    }

    @Test fun `altitudes must be finite and inside the supported range`() {
        for (altitude in listOf(-1000.01, 100000.01, Double.NaN, Double.POSITIVE_INFINITY, Double.NEGATIVE_INFINITY)) {
            assertNull(PhotoLocation.from(valid + ("altitude" to altitude)))
        }
        for (altitude in listOf(null, -1000.0, -12.5, 0.0, 100000.0)) {
            assertNotNull(PhotoLocation.from(valid + ("altitude" to altitude)))
        }
    }
}
