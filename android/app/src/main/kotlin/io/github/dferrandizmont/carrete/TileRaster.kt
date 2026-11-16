package io.github.dferrandizmont.carrete

import java.nio.ByteBuffer
import java.nio.ByteOrder

/** Validates an exact raster of tiles; gaps, duplicates and stale tokens never publish. */
internal class TileRaster(val width: Int, val height: Int, val side: Int, framed: Boolean = false) {
    private var nextX = 0
    private var nextY = 0
    val complete: Boolean get() = nextY == height

    init {
        validateDimensions(width, height, framed)
        require(side in 1..1024)
    }

    companion object {
        fun validateDimensions(width: Int, height: Int, framed: Boolean = false) {
            // Only framed photos may add the largest white border (1.12 * 1.26).
            val maxSide = if (framed) 10324 else 8192
            val maxPixels = if (framed) 71_000_000L else 50_000_000L
            require(width in 1..maxSide && height in 1..maxSide) { "bad image dimensions" }
            require(width.toLong() * height <= maxPixels) { "too many image pixels" }
        }
    }

    /** Bulk-reads a row at a time; only a <=4 KiB int array lives on the Java heap. */
    fun copy(
        x: Int, y: Int, w: Int, h: Int, pixels: ByteBuffer,
        writeRow: (Int, Int, IntArray) -> Unit,
    ) {
        require(!complete && x == nextX && y == nextY) { "out of order tile" }
        require(w == minOf(side, width - x) && h == minOf(side, height - y)) { "bad tile size" }
        require(pixels.remaining().toLong() == w.toLong() * h * 4L) { "bad tile bytes" }
        val rgba = pixels.order(ByteOrder.LITTLE_ENDIAN).asIntBuffer()
        val row = IntArray(w)
        repeat(h) { dy ->
            rgba.get(row)
            repeat(w) { dx ->
                // Little-endian RGBA is ABGR as an int. Swap R/B, preserving
                // straight alpha: setPixels performs the sole premultiplication.
                val abgr = row[dx]
                row[dx] = (abgr and 0xff00ff00.toInt()) or
                    ((abgr and 255) shl 16) or ((abgr ushr 16) and 255)
            }
            writeRow(x, y + dy, row)
        }
        pixels.position(pixels.limit())
        nextX += w
        if (nextX == width) {
            nextX = 0
            nextY += h
        }
    }
}
