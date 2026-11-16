package io.github.dferrandizmont.carrete

import java.io.File
import java.io.FileNotFoundException
import java.io.IOException
import java.nio.file.Path
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class SavedJpegTest {
    @get:Rule val folder = TemporaryFolder()

    @Test
    fun `I O and permission failures propagate to lookup_failed`() {
        val file = folder.newFile("unreadable.jpg")
        file.writeBytes(byteArrayOf(0xff.toByte(), 0xd8.toByte(), 0xff.toByte(), 0xd9.toByte()))
        for (failure in listOf(IOException("storage unavailable"), SecurityException("permission denied"), FileNotFoundException("permission denied"))) {
            for (failMetadata in listOf(true, false)) {
                val unreadable = object : File(file.path) {
                    override fun toPath(): Path = if (failMetadata) throw failure else file.toPath()
                    override fun getPath(): String = throw failure
                }
                val error = assertThrows(failure.javaClass) { isSavedJpeg(unreadable) }
                assertSame(failure, error)
            }
        }
    }

    @Test
    fun `a file lost between metadata checks and opening is not saved`() {
        val file = folder.newFile("gone.jpg")
        file.writeBytes(byteArrayOf(0xff.toByte(), 0xd8.toByte(), 0xff.toByte(), 0xd9.toByte()))
        val disappeared = object : File(file.path) {
            override fun toPath(): Path = file.toPath()
            override fun getPath(): String {
                file.delete()
                return file.path
            }
        }
        assertFalse(isSavedJpeg(disappeared))
        assertFalse(file.exists())
    }

    @Test
    fun `only a readable completed JPEG is accepted`() {
        val file = folder.newFile("photo.jpg")
        assertFalse(isSavedJpeg(file))
        for (bytes in listOf(
            byteArrayOf(0xff.toByte()),
            byteArrayOf(1, 2, 3, 4),
            byteArrayOf(0xff.toByte(), 0xd8.toByte(), 1, 2),
            byteArrayOf(1, 2, 0xff.toByte(), 0xd9.toByte()),
        )) {
            file.writeBytes(bytes)
            assertFalse(isSavedJpeg(file))
        }
        file.writeBytes(byteArrayOf(0xff.toByte(), 0xd8.toByte(), 1, 0xff.toByte(), 0xd9.toByte()))
        assertTrue(isSavedJpeg(file))
        assertTrue(file.delete())
        assertFalse(isSavedJpeg(file))
        assertFalse(isSavedJpeg(folder.root))
    }
}
