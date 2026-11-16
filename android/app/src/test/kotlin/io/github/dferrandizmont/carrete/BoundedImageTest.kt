package io.github.dferrandizmont.carrete

import java.io.ByteArrayInputStream
import java.io.InputStream
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class BoundedImageTest {
    @Test
    fun `unknown sizes start small and grow geometrically`() {
        for (size in listOf(null, -1L, 0L, 3L)) {
            val capacities = mutableListOf<Int>()
            val payload = ByteArray(300 * 1024) { it.toByte() }
            val source = ByteArrayInputStream(payload)
            val input = object : InputStream() {
                override fun read() = source.read()
                override fun read(bytes: ByteArray, offset: Int, length: Int): Int {
                    if (capacities.lastOrNull() != bytes.size) capacities.add(bytes.size)
                    return source.read(bytes, offset, length)
                }
            }
            assertArrayEquals(payload, readBoundedImage(input, size, 64 * 1024 * 1024))
            val expected = listOf(64 * 1024, 128 * 1024, 256 * 1024, 512 * 1024)
            assertEquals(if (size != null && size > 0) listOf(size.toInt()) + expected else expected, capacities)
        }
    }

    @Test
    fun `growth caps at the exact limit and rejects only its next byte`() {
        val limit = 300 * 1024
        for (size in listOf(null, -1L, 0L, 3L, limit.toLong())) {
            val bytes = ByteArray(limit) { it.toByte() }
            assertArrayEquals(bytes, readBoundedImage(ByteArrayInputStream(bytes), size, limit))
            val input = ByteArrayInputStream(ByteArray(limit + 2))
            val error = assertThrows(SecurityException::class.java) { readBoundedImage(input, size, limit) }
            assertEquals("image too large", error.message)
            assertEquals(1, input.available())
        }
    }

    @Test
    fun `reported oversize is rejected before reading`() {
        val input = ByteArrayInputStream(ByteArray(9))
        val error = assertThrows(SecurityException::class.java) { readBoundedImage(input, 9, 8) }
        assertEquals("image too large", error.message)
        assertEquals(9, input.available())
    }

    @Test
    fun `unknown and underreported streams stop at the first excess byte`() {
        for (size in listOf(null, -1L, 0L, 3L, 7L, 8L)) {
            val input = ByteArrayInputStream(ByteArray(20))
            val error = assertThrows(SecurityException::class.java) { readBoundedImage(input, size, 8) }
            assertEquals("image too large", error.message)
            assertEquals(11, input.available())
        }
    }

    @Test
    fun `short exact and empty images preserve their bytes despite stale sizes`() {
        for (length in listOf(0, 3, 8)) {
            val bytes = ByteArray(length) { it.toByte() }
            for (size in listOf(null, -1L, 0L, 2L, 7L, 8L)) {
                assertArrayEquals(bytes, readBoundedImage(ByteArrayInputStream(bytes), size, 8))
            }
        }
    }
}
