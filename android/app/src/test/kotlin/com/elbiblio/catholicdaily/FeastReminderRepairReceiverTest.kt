package com.elbiblio.catholicdaily

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class FeastReminderRepairReceiverTest {
    @Test
    fun `system repair actions have explicit reasons`() {
        assertEquals(
            "timezoneChanged",
            FeastReminderRepairReceiver.reasonForAction("android.intent.action.TIMEZONE_CHANGED"),
        )
        assertEquals(
            "timeSet",
            FeastReminderRepairReceiver.reasonForAction("android.intent.action.TIME_SET"),
        )
        assertEquals(
            "bootCompleted",
            FeastReminderRepairReceiver.reasonForAction("android.intent.action.BOOT_COMPLETED"),
        )
        assertEquals(
            "packageReplaced",
            FeastReminderRepairReceiver.reasonForAction("android.intent.action.MY_PACKAGE_REPLACED"),
        )
        assertEquals(
            "exactAlarmCapabilityChanged",
            FeastReminderRepairReceiver.reasonForAction(
                "android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED",
            ),
        )
    }

    @Test
    fun `unrelated broadcasts are ignored`() {
        assertNull(FeastReminderRepairReceiver.reasonForAction("example.UNRELATED"))
    }
}
