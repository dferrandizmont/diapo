package io.github.dferrandizmont.carrete

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class OriginalRulesTest {
    private val ours = "io.github.dferrandizmont.carrete"

    @Test
    fun `an original written by this app is ours`() {
        assertTrue(OriginalRules.isOurs(ours, ours))
    }

    @Test
    fun `an original of another app is never ours`() {
        assertFalse(OriginalRules.isOurs("com.example.other", ours))
    }

    @Test
    fun `an original with no known owner is never ours`() {
        assertFalse(OriginalRules.isOurs(null, ours))
        assertFalse(OriginalRules.isOurs("", ours))
    }
}
