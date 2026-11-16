package io.github.dferrandizmont.carrete

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class MissingRulesTest {
    @Test
    fun aFileIsGoneOnlyWhenTheStorageAndTheAlbumCanBeRead() {
        assertTrue(MissingRules.fileIsMissing(storageMounted = true, albumReadable = true, fileExists = false))
        assertFalse(MissingRules.fileIsMissing(storageMounted = true, albumReadable = true, fileExists = true))
    }

    @Test
    fun withTheCardOutOrTheAlbumUnreadableNothingIsGone() {
        assertFalse(MissingRules.fileIsMissing(storageMounted = false, albumReadable = true, fileExists = false))
        assertFalse(MissingRules.fileIsMissing(storageMounted = true, albumReadable = false, fileExists = false))
        assertFalse(MissingRules.fileIsMissing(storageMounted = false, albumReadable = false, fileExists = false))
    }

    @Test
    fun theSelectionNamesEveryId() {
        assertEquals("_id IN (4,7,12)", MissingRules.idSelection(listOf(4L, 7L, 12L)))
    }
}
