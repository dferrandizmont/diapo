package io.github.dferrandizmont.carrete

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assume.assumeNoException
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.nio.file.Files

class ContactSheetFileTest {
    @get:Rule val temp = TemporaryFolder()

    @Test fun `allows only direct children of the sheet cache`() {
        val cache = temp.newFolder("cache")
        val sheet = File(cache, "contact-sheets/sheet.jpg")
        assertEquals(sheet.canonicalFile, contactSheetFile(sheet.path, cache))
        for (path in listOf(
            "contact-sheets/sheet.jpg",
            File(cache, "contact-sheets").path,
            File(cache, "sheet.jpg").path,
            File(cache, "contact-sheets-other/sheet.jpg").path,
            File(cache, "contact-sheets/../sheet.jpg").path,
            File(cache, "contact-sheets/nested/../sheet.jpg").path,
            File(cache, "contact-sheets/bad\u0000.jpg").path,
            File(temp.root, "outside.jpg").path,
        )) {
            assertThrows(SecurityException::class.java) { contactSheetFile(path, cache) }
        }
    }

    @Test fun `rejects a nested sheet path`() {
        val cache = temp.newFolder("cache")
        val nested = File(cache, "contact-sheets/nested").apply { mkdirs() }
        val sheet = File(nested, "sheet.png").apply { writeText("sheet") }
        assertThrows(SecurityException::class.java) { contactSheetFile(sheet.path, cache) }
    }

    @Test fun `rejects symlink files and subfolders even with an allowed target`() {
        val cache = temp.newFolder("cache")
        val folder = File(cache, "contact-sheets").apply { mkdirs() }
        val sheet = File(folder, "sheet.jpg").apply { writeText("sheet") }
        val nested = File(folder, "nested").apply { mkdir() }
        val outside = temp.newFile("outside.jpg")
        for ((name, target) in listOf("inside.jpg" to sheet, "outside.jpg" to outside, "alias" to nested)) {
            val link = File(folder, name)
            createLink(link, target)
            val path = if (target.isDirectory) File(link, "sheet.png").path else link.path
            assertThrows(SecurityException::class.java) { contactSheetFile(path, cache) }
        }
    }

    @Test fun `rejects a link back to the cache itself`() {
        val cache = temp.newFolder("cache")
        val folder = File(cache, "contact-sheets").apply { mkdirs() }
        val alias = File(folder, "alias")
        createLink(alias, cache)
        assertThrows(SecurityException::class.java) {
            contactSheetFile(File(alias, "contact-sheets/sheet.jpg").path, cache)
        }
        assertThrows(SecurityException::class.java) {
            contactSheetFile(File(alias, "./contact-sheets/sheet.jpg").path, cache)
        }
    }

    @Test fun `rejects a linked sheet root`() {
        val cache = temp.newFolder("cache")
        val folder = File(cache, "contact-sheets")
        createLink(folder, temp.newFolder("outside"))
        assertThrows(SecurityException::class.java) {
            contactSheetFile(File(folder, "sheet.jpg").path, cache)
        }
    }

    @Test fun `rejects a symlink cycle as not allowed`() {
        val cache = temp.newFolder("cache")
        val folder = File(cache, "contact-sheets").apply { mkdirs() }
        val cycle = File(folder, "cycle.jpg")
        createLink(cycle, cycle)
        assertThrows(SecurityException::class.java) { contactSheetFile(cycle.path, cache) }
    }

    private fun createLink(link: File, target: File) {
        try {
            Files.createSymbolicLink(link.toPath(), target.toPath())
        } catch (e: Exception) {
            // Windows may not grant the test process symlink creation rights.
            assumeNoException(e)
        }
    }
}
