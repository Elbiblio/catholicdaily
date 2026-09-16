# Fast Startup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render the app immediately while retaining notification repair, delivery, and notification-tap behavior.

**Architecture:** Keep `main()` limited to synchronous platform registration and `runApp()`. Run plugin, network, and schedule maintenance after the first Flutter frame; use locale-based region initialization without network latency. Home starts reading resolution alongside low-priority persistence restoration.

**Tech Stack:** Flutter/Dart, Firebase Messaging, WorkManager, flutter_local_notifications, SharedPreferences, flutter_test.

---

## File structure

- Create: `lib/app_startup_maintenance.dart` — one coalesced, error-isolated post-frame maintenance run.
- Create: `test/app_startup_maintenance_test.dart` — coordinator behavior.
- Modify: `lib/main.dart` — removes all pre-`runApp()` awaits and schedules retained post-frame maintenance.
- Modify: `lib/data/services/liturgical_region_preference_service.dart` — locale-only missing-region initialization.
- Create: `test/data/services/liturgical_region_preference_service_test.dart` — local region behavior.
- Modify: `lib/ui/screens/home_screen.dart` — immediate shell with asynchronous persistence restoration.

### Task 1: Post-frame maintenance coordinator

**Files:**
- Create: `lib/app_startup_maintenance.dart`
- Test: `test/app_startup_maintenance_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
test('coalesces concurrent maintenance requests', () async {
  final gate = Completer<void>();
  var calls = 0;
  final maintenance = AppStartupMaintenance(() async {
    calls++;
    await gate.future;
  });
  final first = maintenance.run();
  final second = maintenance.run();
  expect(calls, 1);
  expect(identical(first, second), isTrue);
  gate.complete();
  await first;
});

test('isolates maintenance failure', () async {
  await AppStartupMaintenance(() async {
    throw StateError('offline');
  }).run();
});
```

- [ ] **Step 2: Verify tests fail**

Run: `flutter test test/app_startup_maintenance_test.dart`

Expected: FAIL because `AppStartupMaintenance` is undefined.

- [ ] **Step 3: Add the minimal coordinator**

```dart
class AppStartupMaintenance {
  AppStartupMaintenance(this._task, {this.onError});
  final Future<void> Function() _task;
  final void Function(Object, StackTrace)? onError;
  Future<void>? _run;

  Future<void> run() => _run ??= _runGuarded();

  Future<void> _runGuarded() async {
    try {
      await _task();
    } catch (error, stackTrace) {
      onError?.call(error, stackTrace);
    }
  }
}
```

- [ ] **Step 4: Verify tests pass and commit**

Run: `flutter test test/app_startup_maintenance_test.dart`

Expected: PASS.

```bash
git add lib/app_startup_maintenance.dart test/app_startup_maintenance_test.dart
git commit -m "feat: add post-frame startup maintenance coordinator"
```

### Task 2: Render before startup maintenance

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/data/services/liturgical_region_preference_service.dart`
- Create: `test/data/services/liturgical_region_preference_service_test.dart`

- [ ] **Step 1: Write failing local-region tests**

```dart
test('detectAndSetIfUnset persists the locale region without HTTP', () async {
  SharedPreferences.setMockInitialValues({});
  final service = await LiturgicalRegionPreferenceService.getInstance();
  final region = await service.detectAndSetIfUnset();
  expect(region, LiturgicalRegion.generalRoman);
  expect(service.hasRegion, isTrue);
});

test('stored region remains authoritative', () async {
  SharedPreferences.setMockInitialValues({'liturgical_region': 'NG'});
  final service = await LiturgicalRegionPreferenceService.getInstance();
  expect(await service.detectAndSetIfUnset(), LiturgicalRegion.nigeria);
});
```

- [ ] **Step 2: Verify tests fail**

Run: `flutter test test/data/services/liturgical_region_preference_service_test.dart`

Expected: FAIL because missing-region detection attempts IP network detection.

- [ ] **Step 3: Refactor `main()` and app state**

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (DefaultFirebaseOptions.isSupported) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(CatholicDailyApp(demoLaunchConfig: DemoLaunchConfig.fromEnvironment()));
}
```

Start `CatholicDailyApp` with system/standard theme values. In `initState`, install the notification-tap handler, asynchronously load theme/onboarding/navigation state, and schedule a retained `AppStartupMaintenance.run()` using `addPostFrameCallback`. The maintenance task owns Firebase init, WorkManager init, locale-region persistence, notification plugin init, auto-setup/rescheduling, and `NotificationStartupSyncDispatcher.dispatch()` with the existing error logging.

Change region initialization to:

```dart
if (hasRegion) return currentRegion;
final region = _detectFromLocale();
await setRegion(region, autoDetected: true);
return region;
```

Delete `_detectFromIp` and its `http`/JSON imports.

- [ ] **Step 4: Verify targeted coverage and commit**

Run: `flutter test test/app_startup_maintenance_test.dart test/data/services/liturgical_region_preference_service_test.dart test/data/services/feast_reminder_background_service_test.dart test/data/services/feast_reminder_messaging_service_test.dart`

Expected: PASS.

```bash
git add lib/main.dart lib/data/services/liturgical_region_preference_service.dart test/data/services/liturgical_region_preference_service_test.dart
git commit -m "perf: render app before startup maintenance"
```

### Task 3: Remove duplicate home hydration

**Files:**
- Modify: `lib/ui/screens/home_screen.dart`
- Test: `test/ui/screens/home_screen_startup_test.dart`

- [ ] **Step 1: Write a failing home-shell test**

```dart
testWidgets('renders the home shell without preloading a duplicate reading set', (tester) async {
  await tester.pumpWidget(MaterialApp(home: HomeScreen(
    themeMode: ThemeMode.system,
    themeStyle: AppThemeStyle.standard,
    onThemeModeChanged: (_) {},
    onThemeStyleChanged: (_) {},
  )));
  expect(find.byType(NavigationBar), findsOneWidget);
});
```

- [ ] **Step 2: Verify test fails**

Run: `flutter test test/ui/screens/home_screen_startup_test.dart`

Expected: FAIL because `HomeScreen` holds the full page behind its duplicate reading loader.

- [ ] **Step 3: Keep one owner for today’s reading hydration**

Remove the home container’s `_loadCurrentReadings`, `ReadingsBackendIo`, and duplicate `OrdoResolverService` startup fields. `PremiumBrowseScreen` already owns the current-day reading query and hydration. Initialize the home shell synchronously, then restore the saved tab/navigation state asynchronously. Capture whether a Bible chapter should resume before writing the new home navigation state.

- [ ] **Step 4: Verify home test and commit**

Run: `flutter test test/ui/screens/home_screen_startup_test.dart test/widget_test.dart`

Expected: PASS.

```bash
git add lib/ui/screens/home_screen.dart test/widget_test.dart
git commit -m "perf: parallelize home startup work"
```

### Task 4: Validate release behavior

**Files:**
- Modify: only validation corrections.

- [ ] **Step 1: Format changed Dart files**

Run: `dart format lib/app_startup_maintenance.dart lib/main.dart lib/data/services/liturgical_region_preference_service.dart lib/ui/screens/home_screen.dart test/app_startup_maintenance_test.dart test/data/services/liturgical_region_preference_service_test.dart test/widget_test.dart`

Expected: all listed files are formatted.

- [ ] **Step 2: Analyze and run the suite**

Run: `flutter analyze && flutter test`

Expected: no analysis diagnostics and passing tests.

- [ ] **Step 3: Build release Android artifact**

Run: `flutter build apk --release`

Expected: `build/app/outputs/flutter-apk/app-release.apk` is created.

- [ ] **Step 4: Measure when a physical device is connected**

Run: `adb shell am force-stop com.elbiblio.catholicdaily; adb shell am start -W -n com.elbiblio.catholicdaily/.MainActivity`

Expected: Android cold launch and first usable home UI are under two seconds on repeatable release/profile runs.
