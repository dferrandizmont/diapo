package io.github.dferrandizmont.carrete

import org.junit.Assert.assertThrows
import org.junit.Test

class ContactSheetDimensionsTest {
    @Test fun `accepts the side and pixel limits`() {
        for ((width, height) in listOf(1 to 1, 4096 to 1, 1 to 4096, 4000 to 4000)) {
            validateContactSheetDimensions(width, height)
        }
    }

    @Test fun `rejects invalid sides and too many pixels`() {
        for ((width, height) in listOf(
            0 to 1, 1 to 0, -1 to 1, 1 to -1,
            4097 to 1, 1 to 4097, 4000 to 4001, 4001 to 4000, 4096 to 4096,
            Int.MAX_VALUE to Int.MAX_VALUE,
        )) {
            assertThrows(IllegalArgumentException::class.java) {
                validateContactSheetDimensions(width, height)
            }
        }
    }
}
