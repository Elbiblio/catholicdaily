package com.elbiblio.catholicdaily

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.net.Uri
import android.os.Bundle

/** Private bridge target used by the auto-registered background-isolate plugin. */
internal class FeastReminderOccurrenceStoreProvider : ContentProvider() {
    private lateinit var store: FeastReminderOccurrenceStore

    override fun onCreate(): Boolean {
        val providerContext = context ?: return false
        store = FeastReminderOccurrenceStore(providerContext)
        return true
    }

    override fun call(method: String, arg: String?, extras: Bundle?): Bundle {
        return when (method) {
            METHOD_CLAIM -> {
                if (arg.isNullOrBlank()) {
                    throw IllegalArgumentException("occurrenceKey is required")
                }
                val celebrationDate = extras?.getString(EXTRA_CELEBRATION_DATE)
                    ?: throw IllegalArgumentException("celebrationDate is required")
                Bundle().apply {
                    putBoolean(RESULT_CLAIMED, store.claim(arg, celebrationDate))
                }
            }
            METHOD_CLAIMED_KEYS -> Bundle().apply {
                putStringArrayList(
                    RESULT_OCCURRENCE_KEYS,
                    ArrayList(store.claimedOccurrenceKeys()),
                )
            }
            else -> throw IllegalArgumentException("Unsupported occurrence store call")
        }
    }

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor? = null

    override fun getType(uri: Uri): String? = null

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int = 0

    companion object {
        const val METHOD_CLAIM = "claim"
        const val METHOD_CLAIMED_KEYS = "claimedKeys"
        const val EXTRA_CELEBRATION_DATE = "celebrationDate"
        const val RESULT_CLAIMED = "claimed"
        const val RESULT_OCCURRENCE_KEYS = "occurrenceKeys"
    }
}
