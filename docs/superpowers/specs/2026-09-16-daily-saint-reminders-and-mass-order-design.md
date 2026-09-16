# Daily saint reminders and Mass-order sequencing

## Scope

Correct the Order of Mass so its insertion points appear at their liturgical
positions. Add durable daily Saint-of-the-Day reminders and make important
feasts and solemnities visible in the reminder horizon at least seven days in
advance. The Android process must not need to remain open for an armed
notification to be delivered.

## Options considered

1. Keep WorkManager as the delivery mechanism. It is appropriate for repair,
   but Android deliberately defers it and it cannot provide a notification at
   the selected time.
2. Start a permanent foreground service after boot. This consumes battery,
   requires a persistent system notification, is subject to modern Android
   background-start restrictions, and still cannot bypass force-stop or a
   denied notification permission.
3. **Use persistent OS local alarms, with boot restoration and WorkManager
   repair.** The OS owns armed reminder delivery while the app is terminated;
   the boot receiver restores persisted alarms and a background worker repairs
   drift after boot, package replacement, time-zone/time changes, or an exact
   alarm permission change. This is the selected approach.

No mobile app can promise delivery when Android notifications are denied, the
app is force-stopped, or an OEM/device policy suppresses alarms. The selected
approach provides the strongest supported behavior and detects/reconciles every
recoverable schedule gap.

## Mass order

`MassFlowScreen` currently renders the complete readings card before both
`between_readings` and `before_gospel`. That makes a section labelled “Before
the Gospel” appear after the Gospel itself.

Replace the single all-readings render step with a liturgical-flow composer:

1. introductory rites and the beginning of the Liturgy of the Word;
2. First Reading, Responsorial Psalm, and Second Reading when appointed;
3. `between_readings` items immediately after their associated non-Gospel
   reading flow;
4. Gospel Acclamation and `before_gospel` items, including the Gospel dialogue;
5. the Gospel reading, after the dialogue;
6. `after_gospel` items and the Eucharistic sequence.

The composer will identify Gospel and acclamation positions rather than rely on
the raw list order. It will preserve the existing cards, narration actions,
selected date, and optional readings. Tests will cover weekdays, Sundays,
alternative readings, and an empty/malformed position fallback so no other
insertion point can silently pass the Gospel.

## Reminder scheduling and recovery

Introduce a pure reminder planner that emits two independent occurrence kinds:

- one Saint-of-the-Day occurrence for every calendar date; and
- a feast/solemnity occurrence for the celebration date, plus one advance
  occurrence seven days earlier for important celebrations. This provides
  advance notice without sending seven duplicate alerts for one celebration.

The planner will build a rolling schedule with a minimum eight-day immediate
horizon and a durable multi-month Android horizon, with deterministic IDs,
tags, payloads, and collision handling. A refresh will always re-arm the next
week before removing obsolete occurrences. Existing preferences determine the
selected delivery time; notification permission and exact-alarm capability are
checked explicitly. When exact alarms are unavailable, reminders remain armed
using Android's allow-while-idle inexact mode and the app records that reduced
timing guarantee for repair/diagnostics.

Local notifications remain the delivery authority when the app is terminated
or offline. On Android, the plugin boot receiver restores the persisted alarm
set. The app-owned boot/time/package receiver will enqueue idempotent repair
work, not attempt to launch the UI or use a foreground service. The repair
worker will rebuild the planner output, reconcile persisted schedule metadata
with pending OS alarms, and retain an outbox marker until reconciliation is
successful. The existing Firebase path remains an optional enhancement; it is
not required for local daily reminder delivery.

iOS will use its bounded local-notification capacity and background repair
request. It cannot start arbitrarily at boot, so the app will always retain the
nearest daily/advance occurrences within the OS capacity and reschedule during
supported background opportunities.

## Tests and acceptance

Write tests before production changes for:

- ordering every Mass insertion point around Gospel and Gospel Acclamation;
- daily Saint, seven-day feast/solemnity advance, day-of, timezone, date
  rollover, and deterministic identity planning;
- boot, package replacement, time change, timezone change, and exact-alarm
  repair request wiring;
- an interrupted schedule retaining the next eight days and recovering without
  the app UI running.

Verify the focused Flutter tests, the full Flutter suite, Android Kotlin unit
tests, static manifest checks, `flutter analyze`, and a debug Android build.
Manual device acceptance must include: schedule reminders, kill the app,
reboot, confirm the next reminder remains armed, then test time-zone and
exact-alarm-permission changes.
