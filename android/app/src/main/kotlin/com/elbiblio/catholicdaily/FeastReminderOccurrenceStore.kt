package com.elbiblio.catholicdaily

import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import java.time.LocalDate

internal interface OccurrenceClaimPersistence {
    fun snapshot(): Map<String, String>

    fun replace(values: Map<String, String>): Boolean
}

/**
 * Process-death-safe, occurrence-keyed claim ledger.
 *
 * Only presentation identity is stored here. Notification copy and calendar
 * rules remain in the versioned Dart payload contract.
 */
internal class FeastReminderOccurrenceStore internal constructor(
    private val persistence: OccurrenceClaimPersistence,
    private val today: () -> LocalDate = LocalDate::now,
) {
    constructor(context: Context) : this(
        SharedPreferencesOccurrenceClaimPersistence(preferences(context)),
    )

    fun claim(occurrenceKey: String, celebrationDate: String): Boolean {
        require(occurrenceKey.isNotBlank()) { "occurrenceKey must not be blank" }
        val parsedCelebrationDate =
            runCatching { LocalDate.parse(celebrationDate) }
                .getOrElse {
                    throw IllegalArgumentException("celebrationDate must use YYYY-MM-DD", it)
                }
        return synchronized(claimLock) {
            val currentDate = today()
            val existing = persistence.snapshot()
            val retained = retainedClaims(existing, currentDate)
            if (retained.containsKey(occurrenceKey)) {
                if (retained.size != existing.size) {
                    persistence.replace(retained)
                }
                return@synchronized false
            }
            retained[occurrenceKey] = parsedCelebrationDate.toString()
            persistence.replace(retained)
        }
    }

    fun claimedOccurrenceKeys(): Set<String> = synchronized(claimLock) {
        val existing = persistence.snapshot()
        val retained = retainedClaims(existing, today())
        if (retained.size != existing.size) {
            persistence.replace(retained)
        }
        retained.keys
    }

    companion object {
        private const val PREFERENCES_NAME = "feast_reminder_occurrence_claims_v1"
        private val claimLock = Any()

        private fun retainedClaims(
            existing: Map<String, String>,
            currentDate: LocalDate,
        ): MutableMap<String, String> = existing.filterValues { rawDate ->
            runCatching { !LocalDate.parse(rawDate).isBefore(currentDate) }
                .getOrDefault(false)
        }.toMutableMap()

        private fun preferences(context: Context): SharedPreferences {
            val applicationContext = context.applicationContext
            val storageContext =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    applicationContext.createDeviceProtectedStorageContext()
                } else {
                    applicationContext
                }
            return storageContext.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
        }
    }
}

private class SharedPreferencesOccurrenceClaimPersistence(
    private val preferences: SharedPreferences,
) : OccurrenceClaimPersistence {
    override fun snapshot(): Map<String, String> =
        preferences.all.mapNotNull { (key, value) ->
            (value as? String)?.let { key to it }
        }.toMap()

    override fun replace(values: Map<String, String>): Boolean {
        val editor = preferences.edit().clear()
        values.forEach(editor::putString)
        return editor.commit()
    }
}
