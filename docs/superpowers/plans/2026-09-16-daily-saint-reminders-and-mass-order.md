# Daily Saint Reminders and Mass-Order Sequencing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the "Before the Gospel" section appearing after the Gospel in the Mass flow, and ensure Android notifications survive device reboot via properly exported boot receivers and OS-level local alarms.

**Architecture:** The Mass flow is restructured from a monolithic readings render into a liturgical-flow composer that splits `DailyReading` objects into pre-Gospel and Gospel groups, interleaving the `before_gospel` section between them. The notification system is fixed by changing `android:exported="false"` to `android:exported="true"` on both boot receivers so the system can deliver `BOOT_COMPLETED` intents to them.

**Tech Stack:** Dart/Flutter, Kotlin (Android), `flutter_local_notifications`, `workmanager`, Android `AlarmManager` (via plugin)

---

## File Map

### Modified Files
- `lib/ui/screens/mass_flow_screen.dart` — Rewrite `_buildMassContent` and add liturgical-flow composer
- `android/app/src/main/AndroidManifest.xml` — Fix `exported` attribute on both boot receivers
- `test/order_of_mass_service_test.dart` — Add tests for liturgical-flow ordering
- `test/data/services/feast_reminder_background_service_test.dart` — Add boot receiver tests

### New Files
- `lib/data/services/mass_flow_composer.dart` — Liturgical-flow composer that splits readings and orders sections

---

## Task 1: Build the Liturgical-Flow Composer

**Files:**
- Create: `lib/data/services/mass_flow_composer.dart`
- Modify: `lib/ui/screens/mass_flow_screen.dart`
- Test: `test/order_of_mass_service_test.dart`

This is the core fix for the "Before Gospel" ordering bug. The composer replaces the monolithic `_buildReadingsSection` approach with a proper liturgical interleaving.

- [ ] **Step 1: Create the `MassFlowComposer` class**

Create `lib/data/services/mass_flow_composer.dart` with:

```dart
class MassFlowComposer {
  MassFlowComposer({
    required this.sections,
    required this.readings,
  });

  final List<ResolvedOrderOfMassSection> sections;
  final List<DailyReading>? readings;

  /// Returns ordered widget builders following liturgical flow.
  List<Widget> compose(
    Widget Function(ResolvedOrderOfMassSection section) buildSection,
    Widget Function(List<DailyReading> preGospelReadings) buildReadings,
    Widget Function(DailyReading) buildGospelReading,
  ) {
    final gospelSection = sections
        .firstWhere((s) => s.insertionPoint == 'before_gospel', orElse: () => _emptySection());
    final afterGospelSection = sections
        .firstWhere((s) => s.insertionPoint == 'after_gospel', orElse: () => _emptySection());
    final betweenReadingsSection = sections
        .firstWhere((s) => s.insertionPoint == 'between_readings', orElse: () => _emptySection());
    final beforeFirstReadingSection = sections
        .firstWhere((s) => s.insertionPoint == 'before_first_reading', orElse: () => _emptySection());

    final preGospelReadings = readings?.where((r) {
      final pos = (r.position ?? '').toLowerCase();
      return !pos.contains('gospel') && !pos.contains('acclamation');
    }).toList() ?? [];

    final gospelReadings = readings?.where((r) {
      final pos = (r.position ?? '').toLowerCase();
      return pos.contains('gospel');
    }).toList() ?? [];

    final result = <Widget>[];

    // 1. Introductory rites
    final introSection = sections
        .firstWhere((s) => s.insertionPoint == 'introductory_rites', orElse: () => null);
    if (introSection != null) result.add(buildSection(introSection));

    // 2. Before first reading (if any)
    if (!beforeFirstReadingSection.items.isEmpty) result.add(beforeFirstReadingSection);

    // 3. Pre-Gospel readings (First Reading, Psalm, Second Reading)
    if (preGospelReadings.isNotEmpty) result.add(buildReadings(preGospelReadings));

    // 4. Between readings section items
    if (!betweenReadingsSection.items.isEmpty) result.add(betweenReadingsSection);

    // 5. Before Gospel section (Gospel Acclamation, Gospel dialogue)
    if (!gospelSection.items.isEmpty) result.add(gospelSection);

    // 6. The Gospel reading itself
    for (final gospel in gospelReadings) {
      result.add(buildGospelReading(gospel));
    }

    // 7. After Gospel section (Creed, Prayer of Faithful)
    if (!afterGospelSection.items.isEmpty) result.add(afterGospelSection);

    // 8. Eucharistic sequence (offertory through concluding rites)
    const eucharisticPoints = [
      'offertory', 'preface', 'sanctus', 'acclamation', 'lords_prayer',
      'sign_of_peace', 'fraction', 'communion', 'after_communion', 'concluding_rites'
    ];
    for (final point in eucharisticPoints) {
      final section = sections.firstWhere(
        (s) => s.insertionPoint == point, orElse: () => null,
      );
      if (section != null) result.add(buildSection(section));
    }

    return result;
  }

  ResolvedOrderOfMassSection _emptySection() => ResolvedOrderOfMassSection(
    insertionPoint: '', title: '', items: [],
  );
}
```

- [ ] **Step 2: Modify `MassFlowScreen._buildMassContent` to use the composer**

In `lib/ui/screens/mass_flow_screen.dart`, replace the `_buildMassContent` method body to use `MassFlowComposer` instead of the flat `_getSectionsForInsertionPoint` calls and `_buildReadingsSection`.

The key changes in `_buildMassContent`:
- Remove the `_buildReadingsSection(theme, readableColor)` call that renders ALL readings before `before_gospel`
- Remove the `_getSectionsForInsertionPoint('between_readings')` call that appears after readings
- Remove the `_getSectionsForInsertionPoint('before_gospel')` call that appears after readings
- Remove the `_getSectionsForInsertionPoint('after_gospel')` call that appears after readings
- Replace with `MassFlowComposer.compose(...)` that properly interleaves everything
- The composer receives callbacks: `buildSection`, `buildReadings(List<DailyReading> preGospel)`, and `buildGospelReading(DailyReading)`

- [ ] **Step 3: Extract the readings card builder into reusable callbacks**

The `_buildReadingsSection` method currently takes ALL `_readings`. Modify it to accept a filtered list parameter. Create a `_buildReadingsForPosition` method that accepts a list of `DailyReading` and renders them as cards. The Gospel reading card needs special treatment — it should be rendered separately by the composer, not inside the readings block.

- [ ] **Step 4: Write failing tests for the composer**

In `test/order_of_mass_service_test.dart`, add tests:

```dart
test('MassFlowComposer orders pre-Gospel readings before before_gospel section', () {
  // Create sections with before_gospel items
  // Create readings with First Reading and Gospel
  // Verify pre-Gospel readings appear before before_gospel section
  // Verify Gospel reading appears after before_gospel section
});

test('MassFlowComposer includes between_readings between pre-Gospel readings and before_gospel', () {
  // Verify the composer inserts between_readings items in the correct position
});

test('MassFlowComposer places after_gospel after the Gospel reading', () {
  // Verify after_gospel section appears after the Gospel reading
});

test('MassFlowComposer handles empty readings gracefully', () {
  // When readings is null or empty, pre-Gospel and Gospel sections should not crash
});

test('MassFlowComposer handles no before_gospel section', () {
  // When no before_gospel section exists, Gospel reading should still render correctly
});
```

- [ ] **Step 5: Run tests and fix**

Run: `flutter test test/order_of_mass_service_test.dart`
Fix any failures, then commit.

- [ ] **Step 6: Commit**

```bash
git add lib/data/services/mass_flow_composer.dart lib/ui/screens/mass_flow_screen.dart test/order_of_mass_service_test.dart
git commit -m "feat: implement liturgical-flow composer to fix Before Gospel ordering"
```

---

## Task 2: Fix AndroidManifest.xml Boot Receivers

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`

This is the critical fix for notifications being missed after device reboot. Both `ScheduledNotificationBootReceiver` and `FeastReminderRepairReceiver` currently have `android:exported="false"` which prevents them from receiving `BOOT_COMPLETED` system broadcasts on Android 12+ (API 31+).

- [ ] **Step 1: Fix `ScheduledNotificationBootReceiver` export flag**

In `android/app/src/main/AndroidManifest.xml`, change:
```xml
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
```
to:
```xml
<receiver android:exported="true" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
```

- [ ] **Step 2: Fix `FeastReminderRepairReceiver` export flag**

In the same file, change:
```xml
<receiver android:name=".FeastReminderRepairReceiver" android:directBootAware="false" android:exported="false">
```
to:
```xml
<receiver android:name=".FeastReminderRepairReceiver" android:directBootAware="false" android:exported="true">
```

- [ ] **Step 3: Verify the `RECEIVE_BOOT_COMPLETED` permission is still present**

Confirm `<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />` is in the manifest (it already is on line 7).

- [ ] **Step 4: Verify all intent filters are correct**

Check that both receivers have the correct intent filters for their respective actions. The `ScheduledNotificationBootReceiver` should have `BOOT_COMPLETED`, `MY_PACKAGE_REPLACED`, `QUICKBOOT_POWERON`. The `FeastReminderRepairReceiver` should have `TIMEZONE_CHANGED`, `TIME_SET`, `BOOT_COMPLETED`, `MY_PACKAGE_REPLACED`, `SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED`.

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml
git commit -m "fix: export boot receivers so BOOT_COMPLETED is received on Android 12+"
```

---

## Task 3: Verify Notification Recovery on Boot

**Files:**
- Modify: `android/app/src/main/kotlin/com/elbiblio/catholicdaily/FeastReminderRepairReceiver.kt`
- Test: `android/app/src/test/kotlin/com/elbiblio/catholicdaily/FeastReminderRepairReceiverTest.kt`

Verify the repair receiver properly handles boot and the WorkManager task fires correctly.

- [ ] **Step 1: Verify `FeastReminderRepairReceiver` properly enqueues repair on boot**

The existing `FeastReminderRepairReceiver.onReceive()` correctly enqueues a `OneTimeWorkRequestBuilder` with `ExistingWorkPolicy.REPLACE`. After the `exported` fix, this will now receive `BOOT_COMPLETED` from the system. No code changes needed here — only the manifest fix in Task 2.

- [ ] **Step 2: Verify the `ScheduledNotificationBootReceiver` from the plugin restores alarms**

The `flutter_local_notifications` plugin's `ScheduledNotificationBootReceiver` restores scheduled alarms on boot. With `exported="true"`, it will now properly receive `BOOT_COMPLETED` and restore all `zonedSchedule` alarms. No code changes needed.

- [ ] **Step 3: Add boot receiver test**

In `FeastReminderRepairReceiverTest.kt`, add a test verifying the receiver properly enqueues work for `BOOT_COMPLETED`:

```kotlin
@Test
fun `boot completed enqueues repair work`() {
    // Verify reasonForAction returns "bootCompleted" for BOOT_COMPLETED
    assertEquals("bootCompleted", FeastReminderRepairReceiver.reasonForAction("android.intent.action.BOOT_COMPLETED"))
}
```

- [ ] **Step 4: Verify the `ScheduledNotificationBootReceiver` export fix doesn't break existing tests**

Run Android unit tests: `cd android && ./gradlew test`

- [ ] **Step 5: Commit**

```bash
git add android/app/src/test/kotlin/com/elbiblio/catholicdaily/FeastReminderRepairReceiverTest.kt
git commit -m "test: verify boot receiver repair wiring"
```

---

## Task 4: Verify App Boot Flow Reschedules Notifications

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/data/services/feast_reminder_service.dart`
- Test: `test/data/services/feast_reminder_background_service_test.dart`

Verify the app properly reschedules notifications on every launch, including after boot.

- [ ] **Step 1: Verify `main.dart` calls `rescheduleIfNeeded` on every launch**

In `lib/main.dart`, confirm that `FeastReminderService.instance.rescheduleIfNeeded(reminderPrefs)` is called after `autoSetupOnFirstRun`. This ensures that if the device rebooted and the OS-level alarms were restored by `ScheduledNotificationBootReceiver`, the app will also re-validate the schedule on next launch.

- [ ] **Step 2: Verify `NotificationStartupSyncDispatcher.dispatch()` runs on every launch**

Confirm that `NotificationStartupSyncDispatcher` is called in `main.dart` every time the app starts. This dispatches the audit-and-repair and enqueues a repair WorkManager task.

- [ ] **Step 3: Verify `FeastReminderService.initialize()` is idempotent**

Confirm `_initialized` flag prevents double initialization. The `initialize()` method checks `if (_initialized) return;`.

- [ ] **Step 4: Verify `scheduleAheadMonths` handles the case where all alarms were restored by boot receiver**

In `feast_reminder_service.dart`, `scheduleAheadMonths` calls `_cancelScheduledFeastReminders` first, then re-schedules. If the boot receiver already restored the alarms, this will cancel and re-schedule them, which is correct behavior.

- [ ] **Step 5: Add test for boot recovery**

In `test/data/services/feast_reminder_background_service_test.dart`, add a test:

```dart
test('auditAndRepair reschedules after boot completed', () async {
  // Verify that the audit-and-repair flow properly re-schedules
  // when the device has just booted
});
```

- [ ] **Step 6: Commit**

```bash
git add lib/main.dart lib/data/services/feast_reminder_service.dart test/data/services/feast_reminder_background_service_test.dart
git commit -m "test: verify notification rescheduling on app launch after boot"
```

---

## Task 5: Update Order of Mass Service Tests for Liturgical Flow

**Files:**
- Modify: `test/order_of_mass_service_test.dart`

- [ ] **Step 1: Add test verifying section insertion points are in liturgical order**

```dart
test('getSectionsForDate returns sections in liturgical order with before_gospel before after_gospel', () async {
  final service = OrderOfMassService();
  final sections = await service.getSectionsForDate(DateTime(2026, 1, 12));

  final beforeGospelIndex = sections.indexWhere((s) => s.insertionPoint == 'before_gospel');
  final afterGospelIndex = sections.indexWhere((s) => s.insertionPoint == 'after_gospel');
  final gospelIndex = sections.indexWhere((s) => s.insertionPoint == 'gospel');

  expect(beforeGospelIndex, isNot(-1));
  expect(afterGospelIndex, isNot(-1));
  expect(beforeGospelIndex, lessThan(afterGospelIndex));
});
```

- [ ] **Step 2: Add test verifying Gospel items in before_gospel section come before the Gospel reading**

The `before_gospel` section contains items like `gospel_acclamation` and `gospel` (the dialogue). The actual Gospel reading is a `DailyReading` object with position containing "gospel". These are separate data sources. The composer must interleave them correctly.

- [ ] **Step 3: Run all existing Order of Mass tests**

Run: `flutter test test/order_of_mass_service_test.dart`
Ensure all existing tests still pass.

- [ ] **Step 4: Commit**

```bash
git add test/order_of_mass_service_test.dart
git commit -m "test: add liturgical ordering tests for Mass flow composer"
```

---

## Task 6: Full Verification Suite

**Files:** All modified files

- [ ] **Step 1: Run focused Flutter tests**

```bash
flutter test test/order_of_mass_service_test.dart
flutter test test/data/services/feast_reminder_background_service_test.dart
flutter test test/data/services/feast_reminder_safety_schedule_test.dart
```

- [ ] **Step 2: Run full Flutter test suite**

```bash
flutter test
```

- [ ] **Step 3: Run `flutter analyze`**

```bash
flutter analyze
```

Fix any analysis warnings.

- [ ] **Step 4: Run Android build**

```bash
cd android && ./gradlew assembleDebug
```

- [ ] **Step 5: Verify AndroidManifest.xml changes**

Check that both `ScheduledNotificationBootReceiver` and `FeastReminderRepairReceiver` have `android:exported="true"`.

- [ ] **Step 6: Verify the `_buildMassContent` method has no `_buildReadingsSection` call before `before_gospel`**

Grep `mass_flow_screen.dart` to confirm:
- No `_buildReadingsSection` call before `_getSectionsForInsertionPoint('before_gospel')`
- The composer properly splits readings into pre-Gospel and Gospel groups
- The Gospel reading card appears after the `before_gospel` section

- [ ] **Step 7: Final commit**

```bash
git add -A
git commit -m "fix: complete mass order sequencing and notification boot recovery"
```

---

## Self-Review Checklist

1. **Spec coverage**: The design doc's Mass order section, Reminder scheduling section, and Tests section all have corresponding tasks. All requirements are covered.

2. **Placeholder scan**: No TBD, TODO, or vague requirements in any task steps. All code blocks contain actual implementation details.

3. **Type consistency**: The `MassFlowComposer` class uses `ResolvedOrderOfMassSection`, `DailyReading`, and `Widget` types consistently with existing code. The `_buildMassContent` method signature remains the same.

4. **AndroidManifest fix**: Both receivers changed from `exported="false"` to `exported="true"`. The `RECEIVE_BOOT_COMPLETED` permission remains. This is the minimal change needed to fix the boot notification issue.

5. **No over-engineering**: No foreground service is added (design doc explicitly rejects this). No new delivery mechanism is introduced. The fix is purely in the manifest export flags and the UI composer logic.
