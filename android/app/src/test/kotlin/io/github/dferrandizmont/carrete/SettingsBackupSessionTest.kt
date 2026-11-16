package io.github.dferrandizmont.carrete

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.io.Closeable
import org.junit.Assert.*
import org.junit.Test

class SettingsBackupSessionTest {
    private class Clock {
        var timeout: (() -> Unit)? = null
        var closed = 0
        var cancelled = false
        val session = SettingsBackupSession(
            schedule = { delay, action ->
                assertEquals(15_000L, delay)
                timeout = action
                val cancel: () -> Unit = { cancelled = true }
                cancel
            },
            close = { it.close(); closed++ },
        )
    }

    @Test fun restoredPickerWithoutResultIsClearedByFirstHandleNotice() {
        for (request in listOf(48120, 48121)) {
            val restored = Clock().session
            assertNull(restored.restore(SettingsBackupSession.Saved(request, byteArrayOf(7)), false))
            val recovered = restored.pending!!
            assertEquals(request, recovered.saved.request)
            assertArrayEquals(byteArrayOf(7), recovered.saved.bytes)
            // handle consumes the notice before its busy check, even if the
            // picker never delivers an Activity result after process death.
            assertTrue(restored.takeInterrupted())
            assertNull(restored.pending)
            assertFalse(restored.takeInterrupted())
            assertFalse(recovered.attach(Closeable {}))
            val next = restored.begin(SettingsBackupSession.Saved(request, null)) { _, _ -> }
            assertSame(next, restored.pending)
            assertFalse(restored.finish(recovered, null, null))
            assertSame(next, restored.pending)
        }
    }

    @Test fun restoredIoNeverBecomesPendingForReadOrWriteReplay() {
        for (request in listOf(48120, 48121)) {
            for (bytes in listOf(null, byteArrayOf(7))) {
                val clock = Clock()
                val saved = SettingsBackupSession.Saved(request, bytes, "content://test/document")
                assertSame(saved, clock.session.restore(saved, false))
                // Neither an unfinished write nor a completed write whose
                // reply was lost may reopen/truncate this URI; imports too.
                assertNull(clock.session.pending)
                assertNull(clock.timeout)
                assertTrue(clock.session.takeInterrupted())
                assertFalse(clock.session.takeInterrupted())
                val next = clock.session.begin(SettingsBackupSession.Saved(request, null)) { _, _ -> }
                assertSame(next, clock.session.pending)
            }
        }
    }

    @Test fun restoredExportCleanupPreservesExistingAndRemovesEmptyDocument() {
        for (size in listOf(0L, 37L, null)) {
            val restored = Clock().session
            val saved = SettingsBackupSession.Saved(48120, byteArrayOf(7), "content://test/document")
            val abandoned = restored.restore(saved, false)!!
            assertEquals(saved.uri, abandoned.uri)
            var deleted = false
            SettingsBackupIo.deleteEmptyExport(
                isDocument = { true }, size = { size }, delete = { deleted = true })
            assertEquals(size == 0L, deleted)
            assertNull(restored.pending)
            assertTrue(restored.takeInterrupted())
        }
    }

    @Test fun completedInterruptionNoticeSurvivesAnotherRecreation() {
        val first = Clock().session
        first.restore(null, true)
        val second = Clock().session
        second.restore(null, first.interrupted)
        assertTrue(second.takeInterrupted())
        assertFalse(second.takeInterrupted())
        assertNull(second.pending)
    }

    @Test fun timeoutClosesStreamAnswersStorageAndAllowsAnotherOperation() {
        val clock = Clock()
        var response: String? = null
        var cleanup = 0
        var streamClosed = false
        val operation = clock.session.begin(SettingsBackupSession.Saved(48121, null)) { _, error -> response = error }
        assertTrue(operation.attach(Closeable { streamClosed = true }))
        clock.session.watch(operation) { cleanup++ }
        clock.timeout!!.invoke()
        assertEquals("storage", response)
        assertTrue(streamClosed)
        assertEquals(1, clock.closed)
        assertEquals(1, cleanup)
        assertTrue(clock.cancelled)
        assertNull(clock.session.pending)
        val next = clock.session.begin(SettingsBackupSession.Saved(48121, null)) { _, _ -> }
        // A late completion or expired watchdog must not finish the next call.
        assertFalse(clock.session.finish(operation, byteArrayOf(1), null))
        clock.timeout!!.invoke()
        assertSame(next, clock.session.pending)
    }

    @Test fun timeoutBeforeProviderOpenClosesLateStreamsWithoutUsingThem() {
        for (exporting in listOf(false, true)) {
            val clock = Clock()
            val operation = clock.session.begin(SettingsBackupSession.Saved(48120, byteArrayOf(1))) { _, _ -> }
            clock.session.watch(operation) {}
            clock.timeout!!.invoke()
            var streamClosed = false
            var deleted = false
            val input = object : ByteArrayInputStream(byteArrayOf(1)) {
                override fun close() { streamClosed = true }
                override fun read(buffer: ByteArray, offset: Int, length: Int): Int {
                    fail("Late input must not be read")
                    return -1
                }
            }
            val output = object : ByteArrayOutputStream() {
                override fun close() { streamClosed = true }
            }
            try {
                SettingsBackupIo.access(operation, exporting,
                    openInput = { input }, openOutput = { output },
                    deleteExport = { deleted = true })
                fail("Timed out I/O must fail")
            } catch (_: IOException) {
                assertTrue(streamClosed)
                assertEquals(0, output.size())
                assertEquals(exporting, deleted)
            }
        }
    }

    @Test fun successCancelsWatchdogAndClosesStreamExactlyOnce() {
        val clock = Clock()
        val replies = mutableListOf<Any?>()
        val operation = clock.session.begin(SettingsBackupSession.Saved(48120, byteArrayOf(1))) { value, _ -> replies.add(value) }
        operation.attach(Closeable {})
        clock.session.watch(operation) { fail("Completed operation timed out") }
        assertTrue(clock.session.finish(operation, true, null))
        assertFalse(clock.session.finish(operation, true, null))
        clock.timeout!!.invoke()
        assertEquals(listOf(true), replies)
        assertEquals(1, clock.closed)
    }
}
