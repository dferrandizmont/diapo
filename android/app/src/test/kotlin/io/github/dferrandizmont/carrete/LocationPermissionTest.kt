package io.github.dferrandizmont.carrete

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LocationPermissionTest {
    @Test fun `approximate permission uses network without requesting fine-only GPS`() {
        assertEquals(listOf("network"), locationProviders(false))
        assertEquals(listOf("gps", "network"), locationProviders(true))
    }

    @Test fun `temporary grant expiry reset and explicit re-enable stay retryable`() {
        val history = LocationPermissionHistory()
        assertEquals("denied", history.state(false, false, false))
        history.onResult(true, true, completed = true)
        assertEquals("granted", history.state(true, true, false))
        assertFalse(history.denied)
        // Android expires a one-time grant without any user denial.
        assertEquals("denied", history.state(false, false, false))
        val restarted = LocationPermissionHistory(history.denied)
        assertEquals("denied", restarted.state(false, false, false))
        restarted.onResult(false, true, completed = true)
        assertEquals("coarseOnly", restarted.state(false, true, false))
        assertFalse(restarted.denied)
    }

    @Test fun `only a completed denial can be permanent and a grant resets it`() {
        val history = LocationPermissionHistory()
        history.onResult(false, false, completed = false)
        assertEquals("denied", history.state(false, false, false))
        history.onResult(false, false, completed = true)
        assertTrue(history.denied)
        assertEquals("denied", history.state(false, false, true))
        assertEquals("permanentlyDenied", history.state(false, false, false))
        // A system settings grant must clear persisted denials too.
        assertEquals("granted", history.state(true, true, false))
        assertFalse(history.denied)
        assertEquals("denied", history.state(false, false, false))
    }
}
