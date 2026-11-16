package io.github.dferrandizmont.carrete

import java.io.File
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class SaveSourceTest {
    @get:Rule val temp = TemporaryFolder()

    @Test
    fun `both save protocols accept only canonical cache files`() {
        val cache = temp.newFolder("cache")
        val nested = File(cache, "import").apply { mkdir() }
        val source = File(nested, "photo.png").apply { writeBytes(byteArrayOf(1)) }
        val path = File(nested, "../import/photo.png").path
        assertEquals(source.canonicalPath, cacheSaveSource(path, cache))
        assertNull(cacheSaveSource(null, cache))

        val sibling = temp.newFolder("cache-sibling")
        val outside = File(sibling, "private.jpg").apply { writeBytes(byteArrayOf(1)) }
        for (invalid in listOf(
            outside.path,
            File(cache, "../cache-sibling/private.jpg").path,
            File(cache, "missing.jpg").path,
            nested.path,
            cache.path,
        )) {
            assertThrows(IllegalArgumentException::class.java) { cacheSaveSource(invalid, cache) }
        }
    }
}
