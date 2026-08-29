package com.elbiblio.catholicdaily

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import dev.fluttercommunity.workmanager.BackgroundWorker
import java.util.concurrent.TimeUnit

internal class FeastReminderRepairReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val reason = reasonForAction(intent.action) ?: return
        val input =
            Data.Builder()
                .putString(BackgroundWorker.DART_TASK_KEY, TASK_NAME)
                .putString("payload_repairReason", reason)
                .putBoolean("payload_forceReschedule", true)
                .build()
        val request =
            OneTimeWorkRequestBuilder<BackgroundWorker>()
                .setInputData(input)
                .setConstraints(Constraints.NONE)
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 15, TimeUnit.MINUTES)
                .build()
        WorkManager.getInstance(context.applicationContext).enqueueUniqueWork(
            REPAIR_WORK_NAME,
            ExistingWorkPolicy.REPLACE,
            request,
        )
    }

    companion object {
        private const val TASK_NAME = "audit-feast-reminder-coverage"
        private const val REPAIR_WORK_NAME = "feast-reminder-coverage-repair"

        internal fun reasonForAction(action: String?): String? =
            when (action) {
                "android.intent.action.TIMEZONE_CHANGED" -> "timezoneChanged"
                "android.intent.action.TIME_SET" -> "timeSet"
                "android.intent.action.BOOT_COMPLETED" -> "bootCompleted"
                "android.intent.action.MY_PACKAGE_REPLACED" -> "packageReplaced"
                "android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED" ->
                    "exactAlarmCapabilityChanged"
                else -> null
            }
    }
}
