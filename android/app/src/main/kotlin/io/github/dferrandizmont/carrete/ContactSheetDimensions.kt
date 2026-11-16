package io.github.dferrandizmont.carrete

/** Bounds the contact-sheet channel independently of full-resolution photo encoding. */
internal fun validateContactSheetDimensions(width: Int, height: Int) {
    require(width in 1..4096 && height in 1..4096) { "bad contact sheet dimensions" }
    require(width.toLong() * height <= 16_000_000L) { "too many contact sheet pixels" }
}
