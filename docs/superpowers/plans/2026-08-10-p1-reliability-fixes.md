# P1 Reliability Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make reminders, date loading, reading navigation, and downloadable Catholic Bible sources reliable under permission denial, rapid interaction, navigation, interruption, and restart.

**Architecture:** Introduce small policy/state helpers for reminder horizons and latest-request ownership, then adapt existing screens and services around them. Preserve existing public call sites where possible, extend reading sessions with liturgical context, and support one validated downloadable Catholic database through the existing source registry.

**Tech Stack:** Flutter 3.35, Dart 3.9, flutter_local_notifications 18, sqflite/sqflite_common_ffi, SharedPreferences, flutter_test.

---

### Task 1: Reminder scheduling policy and persisted horizon

**Files:**
- Create: `lib/data/services/feast_reminder_schedule_policy.dart`
- Create: `test/data/services/feast_reminder_schedule_policy_test.dart`
- Modify: `lib/data/services/feast_reminder_preferences.dart`
- Modify: `lib/data/services/feast_reminder_service.dart`

- [ ] **Step 1: Write failing policy tests**

Test that a missing/expired/near horizon requires replenishment, a healthy horizon does not, and exact capability selects `exactAllowWhileIdle` while denial selects `inexactAllowWhileIdle`.

```dart
expect(policy.needsReschedule(now: now, scheduledThrough: null, schemaMatches: true), isTrue);
expect(policy.needsReschedule(now: now, scheduledThrough: now.add(const Duration(days: 10)), schemaMatches: true), isTrue);
expect(policy.needsReschedule(now: now, scheduledThrough: now.add(const Duration(days: 90)), schemaMatches: true), isFalse);
expect(policy.androidMode(exactAllowed: false), AndroidScheduleMode.inexactAllowWhileIdle);
```

- [ ] **Step 2: Run the test and verify RED**

Run: `flutter test test/data/services/feast_reminder_schedule_policy_test.dart`

Expected: FAIL because `FeastReminderSchedulePolicy` does not exist.

- [ ] **Step 3: Implement the minimal pure policy and horizon preference**

Add `FeastReminderSchedulePolicy` with a 30-day replenishment lead and `androidMode`. Add `scheduledThrough` and `setScheduledThrough` using an epoch-millisecond SharedPreferences key. Keep the legacy year key readable only for migration; new decisions use the timestamp.

- [ ] **Step 4: Run the policy test and verify GREEN**

Run: `flutter test test/data/services/feast_reminder_schedule_policy_test.dart`

Expected: PASS.

- [ ] **Step 5: Write failing service-result tests**

Add tests around a pure result finalizer proving that zero successful schedules with eligible occurrences does not advance the horizon, while partial success records the last successfully scheduled occurrence.

```dart
expect(result.shouldPersistHorizon, isFalse);
expect(partial.scheduledThrough, DateTime(2026, 10, 1, 9));
```

- [ ] **Step 6: Run the result tests and verify RED**

Expected: FAIL because the result/finalizer API is absent.

- [ ] **Step 7: Integrate exact/inexact capability and truthful persistence**

Use `canScheduleExactNotifications()` before scheduling. Request exact-alarm permission as a best-effort enhancement when reminders are enabled, but retain notification permission as the enablement gate. Return `FeastReminderScheduleResult`; count attempts, successes, and failures; persist schema/horizon only for success or a genuinely empty eligible range.

- [ ] **Step 8: Run reminder-focused tests and verify GREEN**

Run: `flutter test test/data/services/feast_reminder_schedule_policy_test.dart test/data/services/nigeria_missal_audit_test.dart`

Expected: PASS.

### Task 2: Latest-request ownership for date screens

**Files:**
- Create: `lib/core/latest_request_guard.dart`
- Create: `test/latest_request_guard_test.dart`
- Modify: `lib/ui/screens/premium_browse_screen.dart`
- Modify: `lib/ui/screens/mass_flow_screen.dart`

- [ ] **Step 1: Write a failing guard test**

```dart
final guard = LatestRequestGuard();
final first = guard.begin();
final second = guard.begin();
expect(guard.isCurrent(first), isFalse);
expect(guard.isCurrent(second), isTrue);
```

- [ ] **Step 2: Run the test and verify RED**

Run: `flutter test test/latest_request_guard_test.dart`

Expected: FAIL because the guard is absent.

- [ ] **Step 3: Implement the minimal guard**

Implement an incrementing integer token with `begin()` and `isCurrent(token)`.

- [ ] **Step 4: Run the test and verify GREEN**

Expected: PASS.

- [ ] **Step 5: Refactor Browse to immutable request snapshots**

Change `_loadReadings` to capture `final date` and `final request`, use `date` for every resolver/catalog/hydration call, build all result values locally, and commit them in one `setState` only when mounted and current. Stale success and error completions must not clear the current loading state.

- [ ] **Step 6: Refactor Mass Flow to reject stale completions**

Capture a request token in `_loadMassForDate`, use the parameter date throughout, and guard both success and error state commits.

- [ ] **Step 7: Run focused and existing widget tests**

Run: `flutter test test/latest_request_guard_test.dart test/widget_test.dart test/widgets/mass_flow_region_header_test.dart`

Expected: PASS.

### Task 3: Reading-session context and replacement navigation

**Files:**
- Create: `test/reading_session_test.dart`
- Create: `test/reading_navigation_test.dart`
- Modify: `lib/data/models/reading_session.dart`
- Modify: `lib/data/services/reading_flow_service.dart`
- Modify: `lib/ui/screens/home_screen.dart`

- [ ] **Step 1: Write a failing session-context test**

Build a session with a non-today `LiturgicalDay` and assert `copyWith` preserves it while index changes.

```dart
final moved = session.copyWith(currentIndex: 1);
expect(moved.liturgicalDay, same(day));
```

- [ ] **Step 2: Run the test and verify RED**

Expected: FAIL because `ReadingSession` has no liturgical day.

- [ ] **Step 3: Add liturgical context to ReadingSession and builder**

Add nullable `LiturgicalDay liturgicalDay` support to the model and `ReadingFlowService.buildSession`.

- [ ] **Step 4: Run the session test and verify GREEN**

Expected: PASS.

- [ ] **Step 5: Write a failing navigator-stack widget test**

Open a reading sequence, trigger Next twice, and assert the navigator can return directly to Home with one pop while the displayed reading retains the selected liturgical date.

- [ ] **Step 6: Run the navigation test and verify RED**

Expected: FAIL because each Next currently pushes and later calls pass `null` liturgical context.

- [ ] **Step 7: Implement replacement navigation**

Add a `replaceCurrent` flag to Home's internal open path. Direct opens use `Navigator.push`; Next/Previous/variant use `Navigator.pushReplacement`. Always pass `_readingSession.liturgicalDay` for session navigation.

- [ ] **Step 8: Run navigation tests and verify GREEN**

Run: `flutter test test/reading_session_test.dart test/reading_navigation_test.dart`

Expected: PASS.

### Task 4: Supported downloadable Catholic source

**Files:**
- Modify: `lib/data/models/bible_source.dart`
- Modify: `lib/data/services/bible_source_registry.dart`
- Modify: `lib/data/services/bible_version_preference.dart`
- Modify: `lib/data/services/readings_backend_io.dart`
- Modify: `lib/ui/widgets/bible_version_switcher.dart`
- Modify: `lib/ui/screens/settings_screen.dart`
- Modify: `test/data/services/bible_source_registry_test.dart`
- Create: `test/data/services/offline_bible_catalog_test.dart`

- [ ] **Step 1: Write failing registry/catalog tests**

Assert Douay-Rheims is a supported downloadable Catholic source backed by `engdra.db`; unsupported ASV/KJV entries are filtered; the server `preinstalled` flag does not imply a local file.

- [ ] **Step 2: Run tests and verify RED**

Run: `flutter test test/data/services/bible_source_registry_test.dart test/data/services/offline_bible_catalog_test.dart`

Expected: FAIL because no supported downloadable source exists.

- [ ] **Step 3: Extend the source model and registry**

Add a local database filename/renderability contract for `userProvidedLocal`, register `douay_rheims`, and expose supported downloadable sources separately from bundled sources.

- [ ] **Step 4: Make preferences source-ID based**

Preserve `setVersion(BibleVersionType)` compatibility while adding `setSourceId(String)` and current-source getters. Migrate existing `rsvce`/`nabre` values unchanged.

- [ ] **Step 5: Open downloaded sources from documents storage**

Teach `ReadingsBackendIo` to use the existing asset path for bundled sources and a validated documents path for `userProvidedLocal` sources. Clear source-specific caches on version change.

- [ ] **Step 6: Restrict catalog/UI to usable sources**

Parse the server response by `dbFilename`; map only registered downloadable sources; compute installed state from a validated local file; build selectors from bundled plus installed downloadable sources.

- [ ] **Step 7: Run registry/catalog/backend tests and verify GREEN**

Expected: PASS.

### Task 5: Atomic Bible download and validation

**Files:**
- Modify: `lib/data/services/offline_bible_service.dart`
- Modify: `lib/ui/screens/settings_screen.dart`
- Create: `test/data/services/offline_bible_download_test.dart`

- [ ] **Step 1: Write failing interrupted-download and invalid-schema tests**

Inject a temporary documents directory and HTTP client. Assert a broken stream or invalid SQLite payload leaves no final `.db`, removes `.part`, and keeps a pre-existing valid final database intact.

- [ ] **Step 2: Run tests and verify RED**

Expected: FAIL because the service writes directly to the final path and validates only existence.

- [ ] **Step 3: Implement temporary download, SQLite validation, and atomic install**

Download to `<db>.part`, close the sink, validate HTTP length when supplied, open read-only, require `books` and `verses`, close, then replace the final file. On every exception delete only the temporary file and rethrow a user-safe failure.

- [ ] **Step 4: Surface failure and refresh availability in Settings**

Show a SnackBar on failure. After success, refresh the catalog and Bible selector availability rather than only toggling the in-dialog object.

- [ ] **Step 5: Run download tests and verify GREEN**

Run: `flutter test test/data/services/offline_bible_download_test.dart test/data/services/offline_bible_catalog_test.dart`

Expected: PASS.

### Task 6: Full verification and emulator evidence

**Files:**
- Modify only if a verification-discovered regression requires a new test and minimal fix.

- [ ] **Step 1: Format and analyze**

Run: `dart format lib test`

Run: `flutter analyze --no-pub`

Expected: no issues.

- [ ] **Step 2: Run the full suite**

Run: `flutter test --no-pub --reporter compact`

Expected: all active tests pass; only intentional opt-in tests may be skipped.

- [ ] **Step 3: Build supported platforms**

Run Android and Windows builds with bounded timeouts. Treat the previously identified web import defect separately unless touched by these changes.

- [ ] **Step 4: Verify on Android emulator**

Check: notification permission granted/exact denied still creates pending reminders; rapid previous/next date taps settle on the last date; reading Next does not grow the back stack; Douay-Rheims downloads, becomes selectable, renders a known verse, and survives relaunch.

- [ ] **Step 5: Review diff and document residual limitations**

Confirm only P1-related files changed, preserve the pre-existing Nigeria/reminder work, and report any platform verification that could not be completed.
