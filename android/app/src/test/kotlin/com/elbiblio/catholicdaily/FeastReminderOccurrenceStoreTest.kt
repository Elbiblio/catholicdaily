package com.elbiblio.catholicdaily

import java.time.LocalDate
import java.util.Collections
import java.util.concurrent.Callable
import java.util.concurrent.Executors
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FeastReminderOccurrenceStoreTest {
    @Test
    fun `claim is durable across store instances`() {
        val persistence = InMemoryOccurrenceClaimPersistence()
        val first = FeastReminderOccurrenceStore(persistence) { LocalDate.parse("2026-08-15") }
        val afterProcessDeath = FeastReminderOccurrenceStore(persistence) { LocalDate.parse("2026-08-15") }

        assertTrue(first.claim("feast:nigeria:2026-08-15:on_day:assumption", "2026-08-15"))
        assertFalse(afterProcessDeath.claim("feast:nigeria:2026-08-15:on_day:assumption", "2026-08-15"))
    }

    @Test
    fun `concurrent claims allow exactly one presentation`() {
        val store = FeastReminderOccurrenceStore(InMemoryOccurrenceClaimPersistence()) {
            LocalDate.parse("2026-08-15")
        }
        val executor = Executors.newFixedThreadPool(8)

        val results = try {
            executor.invokeAll(
                List(32) {
                    Callable {
                        store.claim(
                            "feast:nigeria:2026-08-15:on_day:assumption",
                            "2026-08-15",
                        )
                    }
                },
            ).map { it.get() }
        } finally {
            executor.shutdownNow()
        }

        assertEquals(1, results.count { it })
    }

    @Test
    fun `claim prunes occurrences after their celebration date`() {
        val persistence = InMemoryOccurrenceClaimPersistence()
        val oldStore = FeastReminderOccurrenceStore(persistence) { LocalDate.parse("2026-08-15") }
        assertTrue(oldStore.claim("old", "2026-08-15"))

        val nextDayStore = FeastReminderOccurrenceStore(persistence) { LocalDate.parse("2026-08-16") }
        assertTrue(nextDayStore.claim("new", "2026-08-16"))

        assertFalse(persistence.snapshot().containsKey("old"))
        assertEquals("2026-08-16", persistence.snapshot()["new"])
    }

    @Test
    fun `claimed keys prune expired occurrences before schedule repair`() {
        val persistence = InMemoryOccurrenceClaimPersistence()
        val oldStore = FeastReminderOccurrenceStore(persistence) { LocalDate.parse("2026-08-15") }
        assertTrue(oldStore.claim("old", "2026-08-15"))
        assertTrue(oldStore.claim("future", "2026-08-16"))

        val repairStore = FeastReminderOccurrenceStore(persistence) { LocalDate.parse("2026-08-16") }

        assertEquals(setOf("future"), repairStore.claimedOccurrenceKeys())
        assertEquals(mapOf("future" to "2026-08-16"), persistence.snapshot())
    }

    @Test(expected = IllegalArgumentException::class)
    fun `claim rejects malformed celebration dates`() {
        FeastReminderOccurrenceStore(InMemoryOccurrenceClaimPersistence()) {
            LocalDate.parse("2026-08-15")
        }.claim("key", "15-08-2026")
    }
}

private class InMemoryOccurrenceClaimPersistence : OccurrenceClaimPersistence {
    private val values = Collections.synchronizedMap(mutableMapOf<String, String>())

    override fun snapshot(): Map<String, String> = synchronized(values) { values.toMap() }

    override fun replace(values: Map<String, String>): Boolean = synchronized(this.values) {
        this.values.clear()
        this.values.putAll(values)
        true
    }
}
