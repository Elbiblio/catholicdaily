# Startup Snapshot Cache Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render a valid, hydrated daily-reading result from local storage while the authoritative resolver refreshes it in the background.

**Architecture:** A versioned `DailyBrowseSnapshotStore` serializes the complete daily browse state and validates date, liturgical region, Bible edition, and calendar generation. `PremiumBrowseScreen` applies a matching snapshot before live resolution, then replaces it with fresh data and warms at most seven days. One shared presentation object reads startup preference fields once.

**Tech Stack:** Flutter/Dart, SharedPreferences, JSON, flutter_test.

---

## File structure

- Create: `lib/data/services/daily_browse_snapshot_store.dart` — snapshot codec, validation, pruning, and atomic preference writes.
- Create: `test/data/services/daily_browse_snapshot_store_test.dart` — snapshot-key, corruption, expiration, and replacement coverage.
- Modify: `lib/ui/screens/premium_browse_screen.dart` — cache-first daily loading and live replacement.
- Create: `lib/app_startup_presentation.dart` — immutable theme/onboarding/navigation bootstrap state.
- Modify: `lib/main.dart` and `lib/ui/screens/home_screen.dart` — use the shared presentation object.
- Create: `test/app_startup_presentation_test.dart` — one-platform-read coverage.

### Task 1: Implement the validated snapshot store

**Files:**

- Create: `lib/data/services/daily_browse_snapshot_store.dart`
- Test: `test/data/services/daily_browse_snapshot_store_test.dart`

- [ ] **Step 1: Write a failing exact-key test**

```dart
test('returns a snapshot only for the exact date, region, edition, and generation', () async {
  final store = DailyBrowseSnapshotStore.forTesting(preferences: preferences);
  await store.save(snapshotFor(date: DateTime(2026, 9, 16), region: 'NG'));

  expect(await store.read(keyFor(date: DateTime(2026, 9, 16), region: 'NG')), isNotNull);
  expect(await store.read(keyFor(date: DateTime(2026, 9, 16), region: 'US')), isNull);
});
```

- [ ] **Step 2: Verify it fails**

Run: `flutter test test/data/services/daily_browse_snapshot_store_test.dart`

Expected: FAIL because `DailyBrowseSnapshotStore` is undefined.

- [ ] **Step 3: Implement the minimal store**

```dart
class DailyBrowseSnapshotStore {
  static const schemaVersion = 1;
  static const _storageKey = 'daily_browse_snapshots_v1';

  Future<DailyBrowseSnapshot?> read(DailyBrowseSnapshotKey key);
  Future<void> save(DailyBrowseSnapshot snapshot);
}

class DailyBrowseSnapshotKey {
  const DailyBrowseSnapshotKey({
    required this.date,
    required this.region,
    required this.bibleVersion,
    required this.generation,
  });
}
```

Use existing `DailyReading.toMap`/`fromMap`. Explicitly serialize the display fields of `LiturgicalDay`, `OrdoYearVariables`, `OptionalCelebration`, `CelebrationReadingSet`, hydrated text/title/preview maps, and psalm-source values. Reject an entire entry with an unknown enum, absent required field, mismatched key, malformed JSON, or a date outside the local `[today, today + 7 days]` window.

- [ ] **Step 4: Add failing corruption and pruning tests**

```dart
test('removes malformed stored JSON and returns no snapshot', () async {
  SharedPreferences.setMockInitialValues({'daily_browse_snapshots_v1': '{not-json'});
  expect(await DailyBrowseSnapshotStore.forTesting(preferences: preferences).read(keyFor()), isNull);
});

test('does not retain a snapshot beyond the seven-day warm window', () async {
  final store = DailyBrowseSnapshotStore.forTesting(preferences: preferences);
  await store.save(snapshotFor(date: DateTime(2026, 9, 24)));
  expect(await store.read(keyFor(date: DateTime(2026, 9, 24))), isNull);
});
```

- [ ] **Step 5: Implement atomic replacement and verify**

Read one document, replace only the matching entry, prune the bounded date window, and make exactly one `setString` write. A failed write must leave the current display unaffected. Run `flutter test test/data/services/daily_browse_snapshot_store_test.dart`; expect PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/data/services/daily_browse_snapshot_store.dart test/data/services/daily_browse_snapshot_store_test.dart
git commit -m "feat: cache validated daily browse snapshots"
```

### Task 2: Show a snapshot before live hydration

**Files:**

- Modify: `lib/ui/screens/premium_browse_screen.dart`
- Test: `test/ui/screens/home_screen_startup_test.dart`

- [ ] **Step 1: Write a failing widget test**

```dart
testWidgets('shows a matching snapshot before delayed live hydration', (tester) async {
  final liveGate = Completer<DailyBrowseSnapshot>();
  await tester.pumpWidget(testApp(
    snapshotStore: FakeSnapshotStore(snapshotFor()),
    liveLoader: () => liveGate.future,
  ));

  expect(find.text('Cached feast title'), findsOneWidget);
  liveGate.complete(snapshotFor(title: 'Fresh feast title'));
  await tester.pumpAndSettle();
  expect(find.text('Fresh feast title'), findsOneWidget);
});
```

- [ ] **Step 2: Verify it fails**

Run: `flutter test test/ui/screens/home_screen_startup_test.dart`

Expected: FAIL because the screen has no snapshot dependency.

- [ ] **Step 3: Implement cache-first loading**

Add optional `DailyBrowseSnapshotStore` and `DailyBrowseLoader` dependencies with production defaults. At the start of `_loadReadings`, form the key from persisted region/version/generation, apply a matching snapshot through the same state fields used by `_applyHydratedReadings`, and start the current live resolver without waiting. A valid cache keeps `_isLoading` false. A live result replaces the state and saves the fresh snapshot. The existing request guard must prevent a stale date from overwriting a newer selection.

- [ ] **Step 4: Add a stale-result regression and verify**

```dart
testWidgets('ignores a live result for a date that is no longer selected', (tester) async {
  // Start a delayed today request, select tomorrow, then complete today.
  // Tomorrow remains visible.
});
```

Run: `flutter test test/ui/screens/home_screen_startup_test.dart test/widget_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/screens/premium_browse_screen.dart test/ui/screens/home_screen_startup_test.dart test/widget_test.dart
git commit -m "perf: render cached daily readings before refresh"
```

### Task 3: Consolidate startup presentation preferences

**Files:**

- Create: `lib/app_startup_presentation.dart`
- Create: `test/app_startup_presentation_test.dart`
- Modify: `lib/main.dart`
- Modify: `lib/ui/screens/home_screen.dart`

- [ ] **Step 1: Write a failing single-read test**

```dart
test('reads theme, onboarding, and resume fields from one preferences instance', () async {
  var calls = 0;
  final state = await AppStartupPresentation.load(() async {
    calls++;
    return preferences;
  });
  expect(calls, 1);
  expect(state.showOnboarding, isFalse);
});
```

- [ ] **Step 2: Verify it fails**

Run: `flutter test test/app_startup_presentation_test.dart`

Expected: FAIL because `AppStartupPresentation` is undefined.

- [ ] **Step 3: Implement and integrate the immutable value**

```dart
class AppStartupPresentation {
  const AppStartupPresentation({
    required this.themeMode,
    required this.themeStyle,
    required this.showOnboarding,
    required this.lastTabIndex,
    required this.resumeChapter,
  });

  static Future<AppStartupPresentation> load(
    Future<SharedPreferences> Function() preferences,
  );
}
```

Read only existing keys with defensive parsing. `CatholicDailyApp` supplies the object to `HomeScreen`; existing preference services remain responsible for writes. The load stays after `runApp` and cannot add a bootstrap wait.

- [ ] **Step 4: Verify and commit**

Run: `flutter test test/app_startup_presentation_test.dart test/widget_test.dart`

Expected: PASS.

```bash
git add lib/app_startup_presentation.dart lib/main.dart lib/ui/screens/home_screen.dart test/app_startup_presentation_test.dart test/widget_test.dart
git commit -m "perf: share startup presentation preferences"
```

### Task 4: Validate the FCM deployment boundary

**Files:** none in Flutter; verify `C:\dev\elb_api-notifications` in a configured deployment environment.

- [ ] **Step 1: Verify server routes and tests**

Run: `php artisan route:list --path=mobile/notification-installations` and `php artisan test --filter=FeastReminderFallbackTest`.

Expected: registration/occurrence routes and the high-priority Android data-only, expiry, retry, and duplicate-suppression tests pass.

- [ ] **Step 2: Run a deployment preflight without exposing secrets**

Confirm `FCM_PROJECT_ID=elbiblio-fae32`, service-account project identity, `FEAST_NOTIFICATION_SERVER_PRIMARY_ENABLED=true`, test-installation rollout permission, healthy scheduler/queue, and a redacted FCM token fingerprint.

- [ ] **Step 3: Run real-device acceptance**

Invalidate one internal installation's local coverage, terminate its Android process, trigger one due occurrence, and confirm exactly one FCM notification before `remote_expires_at`. Restore valid coverage and confirm no FCM duplicate.

### Task 5: Release validation

- [ ] **Step 1: Format and analyze**

Run: `dart format lib/app_startup_presentation.dart lib/data/services/daily_browse_snapshot_store.dart lib/main.dart lib/ui/screens/home_screen.dart lib/ui/screens/premium_browse_screen.dart test/app_startup_presentation_test.dart test/data/services/daily_browse_snapshot_store_test.dart test/ui/screens/home_screen_startup_test.dart && flutter analyze`

Expected: no diagnostics.

- [ ] **Step 2: Run the full suite and release build**

Run: `flutter test && flutter build apk --release`

Expected: all tests pass and the APK is created. Measure repeatable cold-start behavior with a connected release-build Android device; no source-only check can guarantee a wall-clock target.
