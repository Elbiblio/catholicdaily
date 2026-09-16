# Daily Saint Reminders and Mass-Order Sequencing

## Scope

Correct the Order of Mass so its insertion points appear at their liturgical positions. Add durable daily Saint-of-the-Day reminders and make important feasts and solemnities visible in the reminder horizon at least seven days in advance. The Android process must not need to remain open for an armed notification to be delivered.

## Options considered

1. Keep WorkManager as the delivery mechanism. It is appropriate for repair, but Android deliberately defers it and it cannot provide a notification at the selected time.
2. Start a permanent foreground service after boot. This consumes battery, requires a persistent system notification, is subject to modern Android background-start restrictions, and still cannot bypass force-stop or a denied notification permission.
3. **Use persistent OS local alarms, with boot restoration and WorkManager repair.** The OS owns armed reminder delivery while the app is terminated; the boot receiver restores persisted alarms and a background worker repairs drift after boot, package replacement, time-zone/time changes, or an exact alarm permission change. This is the selected approach.

No mobile app can promise delivery when Android notifications are denied, the app is force-stopped, or an OEM/device policy suppresses alarms. The selected approach provides the strongest supported behavior and detects/reconciles every recoverable schedule gap.

## Mass order

`MassFlowScreen` currently renders the complete readings card before both `between_readings` and `before_gospel`. That makes a section labelled "Before the Gospel" appear after the Gospel itself. Additionally, the `_buildReadingsSection` widget renders ALL readings (First Reading, Psalm, Second Reading, Gospel Acclamation, and the Gospel reading) as a single monolithic block, and the `between_readings` insertion point items are silently skipped because their `variable` items with `source == "readings"` have no inline content.

Replace the single all-readings render step with a liturgical-flow composer:

1. introductory rites and the beginning of the Liturgy of the Word;
2. First Reading, Responsorial Psalm, and Second Reading when appointed;
3. `between_readings` items immediately after their associated non-Gospel reading flow;
4. Gospel Acclamation and `before_gospel` items, including the Gospel dialogue;
5. the Gospel reading, after the dialogue;
6. `after_gospel` items and the Eucharistic sequence.

The composer will identify Gospel and acclamation positions from the `DailyReading` list rather than relying on the raw list order or the `_readings` block. It will:

- Split the existing readings list into pre-Gospel readings and the Gospel reading by matching each `DailyReading.position` against known liturgical position patterns;
- Render pre-Gospel readings (First Reading, Responsorial Psalm, Second Reading) via `_buildReadingsSection` or an equivalent card builder;
- Insert the `before_gospel` section (Gospel Acclamation, Gospel dialogue) between the pre-Gospel readings and the Gospel reading;
- Render the Gospel reading card after the Gospel dialogue;
- Render the `after_gospel` section (Creed, Prayer of the Faithful) after the Gospel.

The composer will preserve the existing cards, narration actions, selected date, and optional readings. Tests will cover weekdays, Sundays, alternative readings, and an empty/malformed position fallback so no other insertion point can silently pass the Gospel.

**Gotcha #2 — Duplicate rendering**: `_buildReadingsSection` renders all `DailyReading` objects as cards, while `between_readings` items from `order_of_mass.json` (Responsorial Psalm, Second Reading) are variable items that get skipped during resolution because they have `type: "variable"` and `source: "readings"` with no inline content. This means the Psalm and Second Reading appear ONLY as reading cards, not as Order of Mass section cards. The composer must ensure these are not duplicated or lost.

**Gotcha #3 — Missing `before_first_reading` sections**: The `_buildMassContent` method includes `_getSectionsForInsertionPoint('before_first_reading')` but this insertion point is empty in `order_of_mass.json`. This is not a bug but should be verified that no items are silently dropped.

**Gotcha #4 — `_getSectionsForInsertionPoint` returns sections in insertion-point string order**: The `OrderOfMassService.getSectionsForDate()` sorts `resolvedItems` by `insertionPoint` alphabetically, then by `order`. The `orderedInsertionPoints` list in `getSectionsForDate` ensures correct ordering of sections returned from the service. However, the `_buildMassContent` method in `MassFlowScreen` independently filters sections by insertion point, so the ordering depends on the order of the `_getSectionsForInsertionPoint` calls in `_buildMassContent`. This must be fixed to follow the liturgical flow defined above.

## Reminder scheduling and recovery

Introduce a pure reminder planner that emits two independent occurrence kinds:

- one Saint-of-the-Day occurrence for each available saint observed on that
  date, while preserving Sunday and higher-rank liturgical precedence; and
- a feast/solemnity occurrence for the celebration date, plus one occurrence on each of the seven preceding days for important celebrations. The series therefore runs from seven days before through the celebration day.

The planner will build a rolling schedule with a minimum eight-day immediate horizon and a durable multi-month Android horizon, with deterministic IDs, tags, payloads, and collision handling. A refresh will always re-arm the next week before removing obsolete occurrences. Existing preferences determine the selected delivery time; notification permission and exact-alarm capability are checked explicitly. When exact alarms are unavailable, reminders remain armed using Android's allow-while-idle inexact mode and the app records that reduced timing guarantee for repair/diagnostics.

Local notifications remain the delivery authority when the app is terminated or offline. On Android, the `flutter_local_notifications` plugin's `ScheduledNotificationBootReceiver` restores the persisted alarm set when the device boots. It remains `android:exported="false"`, as required by the plugin. Android still delivers system broadcasts to a private receiver; the explicit value satisfies Android 12 while preventing other apps from invoking it.

The app-owned `FeastReminderRepairReceiver` handles `BOOT_COMPLETED`, `TIMEZONE_CHANGED`, `TIME_SET`, `MY_PACKAGE_REPLACED`, and `SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED` by enqueueing idempotent WorkManager repair work. It also remains private because every accepted action is a system broadcast. The repair work rebuilds the planner output, reconciles persisted schedule metadata with pending OS alarms, and retains an outbox marker until reconciliation is successful.

The existing Firebase path remains an optional enhancement; it is not required for local daily reminder delivery.

**Critical manifest fix**: Both `ScheduledNotificationBootReceiver` and `FeastReminderRepairReceiver` declare an explicit `android:exported` value for Android 12 compatibility, but remain `false`. The manifest includes `RECEIVE_BOOT_COMPLETED`; boot delivery and alarm restoration are verified by manifest and receiver tests.

**WorkManager is not the delivery mechanism**: WorkManager tasks are deferred and cannot guarantee exact-time notification delivery. The `ScheduledNotificationBootReceiver` from `flutter_local_notifications` restores OS-level alarms via `zonedSchedule` which creates `AlarmManager` alarms. The `FeastReminderRepairReceiver` only enqueues a repair WorkManager task to re-schedule any drifted alarms. The actual notification delivery is always via `flutter_local_notifications` plugin alarms, never via WorkManager.

iOS will use its bounded local-notification capacity and background repair request. It cannot start arbitrarily at boot, so the app will always retain the nearest daily/advance occurrences within the OS capacity and reschedule during supported background opportunities.

## Tests and acceptance

Write tests before production changes for:

- ordering every Mass insertion point around Gospel and Gospel Acclamation;
- splitting readings into pre-Gospel and Gospel groups without duplication;
- daily Saint, every day in the seven-day feast/solemnity countdown, day-of, timezone, date rollover, and deterministic identity planning;
- boot, package replacement, time change, timezone change, and exact-alarm repair request wiring;
- an interrupted schedule retaining the next eight days and recovering without the app UI running;
- AndroidManifest.xml private boot-receiver verification.

Verify the focused Flutter tests, the full Flutter suite, Android Kotlin unit tests, static manifest checks, `flutter analyze`, and a debug Android build. Manual device acceptance must include: schedule reminders, kill the app, reboot, confirm the next reminder remains armed, then test time-zone and exact-alarm-permission changes.
