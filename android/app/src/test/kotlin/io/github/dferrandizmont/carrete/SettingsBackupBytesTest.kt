package io.github.dferrandizmont.carrete

import java.io.ByteArrayInputStream
import java.io.InputStream
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Test

class SettingsBackupBytesTest {
    @Test fun emptyAndExactLimitAreAccepted() {
        for (size in listOf(0, 37, SettingsBackupBytes.MAX_BYTES)) {
            val bytes = ByteArray(size) { (it % 251).toByte() }
            assertArrayEquals(bytes, SettingsBackupBytes.read(ByteArrayInputStream(bytes)))
        }
    }

    @Test(expected = SettingsBackupBytes.TooLarge::class)
    fun oneByteOverLimitIsRejected() {
        SettingsBackupBytes.read(ByteArrayInputStream(ByteArray(SettingsBackupBytes.MAX_BYTES + 1)))
    }

    @Test fun unboundedStreamIsStoppedAfterLimitPlusOne() {
        var read = 0
        val input = object : InputStream() {
            override fun read(): Int { read++; return 1 }
        }
        try {
            SettingsBackupBytes.read(input)
            throw AssertionError("Expected size rejection")
        } catch (_: SettingsBackupBytes.TooLarge) {
            assertEquals(SettingsBackupBytes.MAX_BYTES + 1, read)
        }
    }

    @Test fun shortReadsDoNotTruncateTheDocument() {
        val bytes = ByteArray(91) { it.toByte() }
        val input = object : ByteArrayInputStream(bytes) {
            override fun read(buffer: ByteArray, offset: Int, length: Int): Int =
                super.read(buffer, offset, minOf(length, 3))
        }
        assertArrayEquals(bytes, SettingsBackupBytes.read(input))
    }
}
