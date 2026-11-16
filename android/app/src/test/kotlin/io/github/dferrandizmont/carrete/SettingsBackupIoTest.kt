package io.github.dferrandizmont.carrete

import java.io.IOException
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import org.junit.Assert.*
import org.junit.Test

class SettingsBackupIoTest {
    @Test fun newOperationsStillReadAndWriteAndReleasePending() {
        val bytes = byteArrayOf(4, 5, 6)
        for (exporting in listOf(false, true)) {
            val session = session()
            val operation = session.begin(SettingsBackupSession.Saved(if (exporting) 48120 else 48121, bytes), null)
            val output = ByteArrayOutputStream()
            val response = SettingsBackupIo.access(operation, exporting,
                openInput = { ByteArrayInputStream(bytes) }, openOutput = { output },
                deleteExport = { fail("Successful operation cannot delete") })
            if (exporting) {
                assertEquals(true, response)
                assertArrayEquals(bytes, output.toByteArray())
            } else assertArrayEquals(bytes, response as ByteArray)
            assertTrue(session.finish(operation, response, null))
            assertNull(session.pending)
        }
    }

    @Test fun missingExportBytesNeverTruncateAndOnlyCleanUpEmptyDocument() {
        val operation = session().begin(SettingsBackupSession.Saved(48120, null), null)
        var opened = false
        var deleted = false
        try {
            SettingsBackupIo.access(operation, true,
                openInput = { null }, openOutput = { opened = true; ByteArrayOutputStream() },
                deleteExport = {
                    SettingsBackupIo.deleteEmptyExport(
                        isDocument = { true }, size = { 0L }, delete = { deleted = true })
                })
            fail("Missing payload must fail")
        } catch (_: IOException) {
            assertFalse(opened)
            assertTrue(deleted)
        }
    }

    @Test fun failureBeforeTruncationOnlyDeletesConfirmedEmptyDocument() {
        for (size in listOf(0L, 37L, null, -1L)) {
            val session = session()
            val operation = session.begin(SettingsBackupSession.Saved(48120, byteArrayOf(7)), null)
            var deleted = false
            try {
                SettingsBackupIo.access(operation, true,
                    openInput = { fail("Export cannot read"); null },
                    openOutput = { throw IOException("Provider refused access before truncation") },
                    deleteExport = {
                        SettingsBackupIo.deleteEmptyExport(
                            isDocument = { true }, size = { size }, delete = { deleted = true })
                    })
                fail("Failed export must report failure")
            } catch (_: IOException) {
                assertEquals(size == 0L, deleted)
            }
        }
    }

    @Test fun timeoutOnlyDeletesConfirmedEmptyDocumentAndReportsStorage() {
        for (size in listOf(0L, 37L, null, -1L)) {
            var timeout: (() -> Unit)? = null
            val session = SettingsBackupSession(
                schedule = { _, action -> timeout = action; {} }, close = { it.close() })
            var error: String? = null
            var deleted = false
            val operation = session.begin(SettingsBackupSession.Saved(48120, byteArrayOf(7))) { _, code ->
                error = code
            }
            session.watch(operation) {
                SettingsBackupIo.deleteEmptyExport(
                    isDocument = { true }, size = { size }, delete = { deleted = true })
            }
            timeout!!.invoke()
            assertEquals("storage", error)
            assertEquals(size == 0L, deleted)
            assertNull(session.pending)
        }
    }

    @Test fun nonDocumentUriIsNeverQueriedOrDeleted() {
        var queried = false
        var deleted = false
        SettingsBackupIo.deleteEmptyExport(
            isDocument = { false },
            size = { queried = true; 0L },
            delete = { deleted = true })
        assertFalse(queried)
        assertFalse(deleted)
    }

    @Test fun failedDocumentCheckOrSizeQueryPreservesDocument() {
        for (failCheck in listOf(false, true)) {
            var deleted = false
            SettingsBackupIo.deleteEmptyExport(
                isDocument = { if (failCheck) throw SecurityException("No grant"); true },
                size = { throw IOException("No metadata") },
                delete = { deleted = true })
            assertFalse(deleted)
        }
    }

    @Test fun refusedDeletionIsBestEffort() {
        var attempted = false
        SettingsBackupIo.deleteEmptyExport(
            isDocument = { true }, size = { 0L },
            delete = { attempted = true; throw SecurityException("Deletion refused") })
        assertTrue(attempted)
    }

    private fun session() = SettingsBackupSession(schedule = { _, _ -> {} }, close = { it.close() })
}
