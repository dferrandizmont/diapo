package io.github.dferrandizmont.carrete

import java.nio.ByteBuffer
import org.junit.Assert.*
import org.junit.Test

class TileRasterTest {
    @Test
    fun `partial edge tiles assemble exactly with RGBA converted to ARGB`() {
        val raster = TileRaster(5, 3, 2)
        val out = IntArray(15)
        for (y in 0 until 3 step 2) for (x in 0 until 5 step 2) {
            val w = minOf(2, 5 - x)
            val h = minOf(2, 3 - y)
            val pixels = ByteBuffer.allocate(w * h * 4)
            for (dy in 0 until h) for (dx in 0 until w) {
                pixels.put((x + dx).toByte()).put((y + dy).toByte()).put(17).put(255.toByte())
            }
            pixels.flip()
            raster.copy(x, y, w, h, pixels) { left, top, row ->
                row.copyInto(out, top * 5 + left)
            }
        }
        assertTrue(raster.complete)
        for (y in 0 until 3) for (x in 0 until 5) {
            assertEquals((255 shl 24) or (x shl 16) or (y shl 8) or 17, out[y * 5 + x])
        }
    }

    @Test
    fun `gaps duplicate tiles malformed buffers and oversize geometry are rejected`() {
        val raster = TileRaster(5, 3, 2)
        val pixels = ByteBuffer.allocate(16)
        assertThrows(IllegalArgumentException::class.java) { raster.copy(2, 0, 2, 2, pixels) { _, _, _ -> } }
        assertThrows(IllegalArgumentException::class.java) { raster.copy(0, 0, 1, 2, pixels) { _, _, _ -> } }
        assertThrows(IllegalArgumentException::class.java) { raster.copy(0, 0, 2, 2, ByteBuffer.allocate(15)) { _, _, _ -> } }
        raster.copy(0, 0, 2, 2, pixels) { _, _, _ -> }
        assertFalse(raster.complete)
        assertThrows(IllegalArgumentException::class.java) { raster.copy(0, 0, 2, 2, ByteBuffer.allocate(16)) { _, _, _ -> } }
        for ((w, h, side) in listOf(Triple(0, 1, 2), Triple(10325, 1, 2), Triple(9000, 9000, 2), Triple(1, 1, 1025))) {
            assertThrows(IllegalArgumentException::class.java) { TileRaster(w, h, side) }
        }
        TileRaster(8160, 6120, 1024)
        TileRaster(7920, 8910, 1024, framed = true) // Largest square photo plus print border.
    }

    @Test
    fun `bulk RGBA conversion preserves straight mid alpha and byte order`() {
        val raster = TileRaster(2, 2, 2)
        // A direct transport buffer with its header already consumed.
        val pixels = ByteBuffer.allocateDirect(20 + 16)
        pixels.position(20)
        repeat(2) {
            pixels.put(200.toByte()).put(100).put(50).put(128.toByte())
            pixels.put(40).put(80).put(120).put(64)
        }
        pixels.flip()
        pixels.position(20)
        val rows = mutableListOf<IntArray>()
        raster.copy(0, 0, 2, 2, pixels) { _, _, row -> rows.add(row.copyOf()) }
        assertTrue(raster.complete)
        assertEquals(pixels.limit(), pixels.position())
        for (row in rows) {
            // setPixels takes these unpremultiplied ARGB colours. Feeding
            // premultiplied channels (100, 50, 25) would darken them twice.
            assertArrayEquals(intArrayOf(0x80c86432.toInt(), 0x40285078), row)
        }
    }

    @Test
    fun `only framed output may exceed photo limits`() {
        for ((w, h) in listOf(8193 to 1, 1 to 8193, 8000 to 6251, 7920 to 8910)) {
            assertThrows(IllegalArgumentException::class.java) { TileRaster(w, h, 1024) }
            assertThrows(IllegalArgumentException::class.java) { TileRaster.validateDimensions(w, h) }
            TileRaster(w, h, 1024, framed = true)
        }
        TileRaster(8192, 1, 1024)
        TileRaster(8000, 6250, 1024)
        for ((w, h) in listOf(10325 to 1, 1 to 10325, 9000 to 9000, 0 to 1)) {
            assertThrows(IllegalArgumentException::class.java) { TileRaster(w, h, 1024, framed = true) }
        }
    }

    @Test
    fun `no pixels after completion are accepted`() {
        val raster = TileRaster(1, 1, 1)
        raster.copy(0, 0, 1, 1, ByteBuffer.allocate(4)) { _, _, _ -> }
        assertTrue(raster.complete)
        assertThrows(IllegalArgumentException::class.java) {
            raster.copy(0, 0, 1, 1, ByteBuffer.allocate(4)) { _, _, _ -> }
        }
    }
}
