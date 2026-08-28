# Durable, Date-Safe Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver factually dated feast reminders offline and while the app process is terminated, with reboot/background replenishment and lease-controlled FCM fallback that does not routinely duplicate local alarms.

**Architecture:** Flutter remains the primary scheduler using OS-owned local notifications and a shared pure notification contract. Android WorkManager maintains a rolling schedule from bundled calendar data. The app registers an anonymous installation and uploads confirmed coverage; Laravel sends a short-lived FCM fallback only for due occurrences outside that coverage, using a calendar catalog exported by the same Dart resolver.

**Tech Stack:** Flutter 3.35/Dart 3.9, `flutter_local_notifications`, `timezone`, `intl`, Firebase Core/Messaging, WorkManager, secure storage, Laravel 11/PHP 8.2, MySQL, Laravel scheduler, FCM HTTP v1, PHPUnit.

---

## File map

### Flutter repository

- Create `lib/data/services/feast_reminder_notification_contract.dart` for pure formatting, occurrence keys, stable IDs, group keys, and generation constants.
- Create `lib/data/services/feast_reminder_schedule_capacity.dart` for platform queue budgets and coverage cutoffs.
- Create `lib/data/services/feast_reminder_background_service.dart` for WorkManager audits.
- Create `lib/data/services/notification_installation.dart`, `notification_installation_store.dart`, and `notification_installation_api.dart` for anonymous registration and coverage sync.
- Create `lib/data/services/feast_reminder_messaging_service.dart` for Firebase lifecycle, foreground rendering, and tap routing.
- Create `tool/generate_feast_notification_catalog.dart` and `assets/data/feast_notification_catalog.json` for the shared server calendar.
- Modify `feast_reminder_payload.dart`, `feast_reminder_preferences.dart`, `feast_reminder_service.dart`, `main.dart`, and notification settings integration.
- Modify Android/iOS Firebase and background configuration plus `pubspec.yaml`/`pubspec.lock`.
- Add focused tests under `test/data/services/` and `test/tool/`.

### Laravel repository

Implementation occurs in `/var/www/elb_api-notifications`, an isolated worktree, so unrelated tracked modifications in `/var/www/elb_api` remain untouched.

- Create notification-installation and delivery-ledger migrations/models.
- Create installation authentication/controller/routes.
- Create the shared catalog reader, fallback service, and scheduled command.
- Extend `PushNotificationService` with token-targeted, bounded FCM v1 sending.
- Copy the generated catalog to `resources/data/feast_notification_catalog.json`.
- Add feature/API/unit tests and a disabled-by-default feature flag.

## Task 1: Establish isolated branches and clean baselines

**Files:**
- Verify only: Flutter working tree and `/var/www/elb_api`

- [ ] **Step 1: Create the Flutter implementation branch**

```powershell
git switch -c codex/durable-date-safe-notifications
git status --short
```

Expected: branch creation succeeds; existing untracked audit/image files remain unmodified.

- [ ] **Step 2: Create a clean Laravel worktree**

```powershell
ssh -i C:\keys\bigbundle.pem -p 1145 patacee@178.79.176.19 "git -C /var/www/elb_api worktree add /var/www/elb_api-notifications -b codex/durable-date-safe-notifications 60d0f63"
```

Expected: new worktree is clean; the deployed directory retains its existing modifications.

- [ ] **Step 3: Run focused baselines**

```powershell
flutter test test/data/services/feast_reminder_payload_test.dart test/data/services/feast_reminder_schedule_policy_test.dart
ssh -i C:\keys\bigbundle.pem -p 1145 patacee@178.79.176.19 "cd /var/www/elb_api-notifications && php artisan test tests/Feature/API/v1/PushNotificationFlowTest.php"
```

Expected: all existing reminder/push tests pass.

## Task 2: Add the pure date-safe notification contract

**Files:**
- Create: `lib/data/services/feast_reminder_notification_contract.dart`
- Test: `test/data/services/feast_reminder_notification_contract_test.dart`

- [ ] **Step 1: Write failing formatter and identity tests**

```dart
test('on-day copy cannot become falsely current', () {
  final content = FeastReminderNotificationContract.content(
    celebrationDate: DateTime(2026, 8, 29),
    title: 'The Passion of Saint John the Baptist',
    rank: 'Memorial',
    dayBefore: false,
    locale: 'en',
  );
  expect(content.title, 'Saturday, 29 August — A Memorial');
  expect(content.expandedBody, contains('Saturday, 29 August'));
  expect(content.title, isNot(contains('Today')));
});

test('identity is stable, regional, and date scoped', () {
  final value = FeastReminderNotificationContract.identity(
    region: 'nigeria',
    celebrationDate: DateTime(2026, 8, 29),
    dayBefore: false,
    celebrationId: 'passion-john-baptist',
  );
  expect(value.occurrenceKey,
      'feast:nigeria:2026-08-29:on_day:passion-john-baptist');
  expect(value.notificationId, greaterThan(0));
  expect(value.groupKey, 'feast_reminders:2026-08-29');
});
```

- [ ] **Step 2: Verify the test fails**

Run: `flutter test test/data/services/feast_reminder_notification_contract_test.dart`

Expected: FAIL because the contract does not exist.

- [ ] **Step 3: Implement the contract**

Create immutable content/identity values. Format `DateFormat('EEEE, d MMMM', locale)`. Build titles such as `Saturday, 29 August — A Memorial` and repeat the absolute date in expanded bodies. Canonicalize keys from type, region, ISO date, timing, and a slugged stable celebration ID. Implement stable UTF-8 FNV-1a IDs:

```dart
static int stableNotificationId(String value) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(value)) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  final positive = hash & 0x7fffffff;
  return positive == 0 ? 1 : positive;
}
```

Define `scheduleGeneration = 'feast-reminders-v5'` in this file.

- [ ] **Step 4: Run tests and commit**

```powershell
flutter test test/data/services/feast_reminder_notification_contract_test.dart
git add lib/data/services/feast_reminder_notification_contract.dart test/data/services/feast_reminder_notification_contract_test.dart
git commit -m "feat: add date-safe feast notification contract"
```

Expected: PASS and a focused commit.

## Task 3: Upgrade payloads without breaking notification taps

**Files:**
- Modify: `lib/data/services/feast_reminder_payload.dart`
- Modify: `test/data/services/feast_reminder_payload_test.dart`

- [ ] **Step 1: Add a failing v2 round-trip test**

```dart
final payload = FeastReminderPayload(
  celebrationDate: DateTime(2026, 8, 29),
  scheduledFor: DateTime.parse('2026-08-29T07:00:00+01:00'),
  occurrenceKey: 'feast:nigeria:2026-08-29:on_day:passion-john-baptist',
  timeZone: 'Africa/Lagos',
  liturgicalRegion: 'nigeria',
  scheduleGeneration: 'feast-reminders-v5',
  title: 'The Passion of Saint John the Baptist',
  rank: 'Memorial',
  saintProfileId: 'passion-john-baptist',
  dayBefore: false,
);
final decoded = FeastReminderPayload.tryParse(payload.encode())!;
expect(decoded.celebrationDate, DateTime(2026, 8, 29));
expect(decoded.occurrenceKey, payload.occurrenceKey);
expect(decoded.liturgicalRegion, 'nigeria');
```

Retain tests for v1 JSON, `feast:YYYY-MM-DD:day`, malformed payloads, and cold-start navigation.

- [ ] **Step 2: Verify the test fails**

Run: `flutter test test/data/services/feast_reminder_payload_test.dart`

Expected: FAIL for the v2 fields.

- [ ] **Step 3: Implement v2 plus compatibility**

Set schema 2, encode `type: feast_reminder`, and add `fromMap`. Accept JSON versions 1/2 and both type names. V1/legacy metadata is nullable; celebration date remains authoritative. Reject v2 maps missing valid `celebration_date` or `occurrence_key`.

- [ ] **Step 4: Run tests and commit**

```powershell
flutter test test/data/services/feast_reminder_payload_test.dart
git add lib/data/services/feast_reminder_payload.dart test/data/services/feast_reminder_payload_test.dart
git commit -m "feat: add date-aware feast reminder payload v2"
```

## Task 4: Apply contract, stable IDs, grouping, and platform capacity

**Files:**
- Create: `lib/data/services/feast_reminder_schedule_capacity.dart`
- Modify: `lib/data/services/feast_reminder_service.dart`
- Modify: `lib/data/services/feast_reminder_preferences.dart`
- Create: `test/data/services/feast_reminder_schedule_capacity_test.dart`
- Modify: `test/data/services/feast_reminder_schedule_policy_test.dart`

- [ ] **Step 1: Write failing capacity tests**

```dart
test('ios keeps a conservative pending budget', () {
  expect(FeastReminderScheduleCapacity.forIos().maximumPending, 60);
});

test('android does not inherit the ios cap', () {
  expect(FeastReminderScheduleCapacity.forAndroid().maximumPending, isNull);
});
```

Also test that a cap/failure stops coverage before the first unscheduled eligible occurrence.

- [ ] **Step 2: Verify capacity tests fail**

Run: `flutter test test/data/services/feast_reminder_schedule_capacity_test.dart`

Expected: FAIL because the capacity class is missing.

- [ ] **Step 3: Implement capacity and scheduler integration**

Create pure Android-unbounded/iOS-60 policies. In `FeastReminderService`, increment schedule schema to 5; replace relative copy; use deterministic ID/tag, date group/sort keys, absolute iOS subtitle, full Android horizon, capped iOS prefix, current region, and payload v2. Use this boundary shape:

```dart
final identity = FeastReminderNotificationContract.identity(
  region: region.name,
  celebrationDate: event.date,
  dayBefore: occurrence.dayBefore,
  celebrationId: event.saintProfileId ?? event.title,
);
final content = FeastReminderNotificationContract.content(
  celebrationDate: event.date,
  title: event.title,
  rank: event.rank,
  dayBefore: occurrence.dayBefore,
  locale: 'en',
);
```

Persist coverage only through the last fully successful prefix. Add preference getters/setters for generation, timezone, and last audit; invalidation removes them.

Persist every scheduled feast notification ID. Replace `cancelAll()` with cancellation of those IDs so feast rescheduling cannot remove unrelated app notifications. Because coverage is date-valued, when the iOS cap splits a date containing multiple occurrences, report the previous fully scheduled celebration date.

- [ ] **Step 4: Run focused tests and commit**

```powershell
flutter test test/data/services/feast_reminder_notification_contract_test.dart test/data/services/feast_reminder_payload_test.dart test/data/services/feast_reminder_schedule_capacity_test.dart test/data/services/feast_reminder_schedule_policy_test.dart
git add lib/data/services/feast_reminder_service.dart lib/data/services/feast_reminder_preferences.dart lib/data/services/feast_reminder_schedule_capacity.dart test/data/services
git commit -m "fix: make feast reminders date-safe and platform-aware"
```

## Task 5: Generate one server calendar catalog from the Dart resolver

**Files:**
- Create: `tool/generate_feast_notification_catalog_test.dart`
- Create: `assets/data/feast_notification_catalog.json`
- Create: `test/tool/generate_feast_notification_catalog_test.dart`
- Modify: `pubspec.yaml`

- [ ] **Step 1: Write a failing deterministic-catalog test**

Invoke `buildCatalog(startYear: 2024, endYear: 2035)` twice inside the Flutter test runtime and assert byte-identical canonical JSON, every supported region, unique occurrence keys and numeric IDs for both timing modes, sorted dates, and Assumption on August 15 in Nigeria.

- [ ] **Step 2: Verify the test fails**

Run: `flutter test tool/generate_feast_notification_catalog_test.dart`

Expected: FAIL because the generator is missing.

- [ ] **Step 3: Implement the generator**

Iterate all civil dates from 2024-01-01 through 2035-12-31 for each reminder-supported `LiturgicalRegion`. Call the same event-preview resolver as `FeastReminderService`; serialize `region`, `date`, `title`, normalized rank, and stable celebration ID. Sort by region/date/rank/ID. Compute SHA-256 over the canonical events array and emit this structure with the real computed digest:

```json
{
  "schema": 1,
  "schedule_generation": "feast-reminders-v5",
  "start_date": "2024-01-01",
  "end_date": "2035-12-31",
  "sha256": "64 lowercase hexadecimal characters produced by the generator",
  "events": []
}
```

- [ ] **Step 4: Generate, test, and commit**

```powershell
flutter pub add crypto
flutter test tool/generate_feast_notification_catalog_test.dart --dart-define=WRITE_FEAST_CATALOG=true
flutter test test/tool/generate_feast_notification_catalog_test.dart
git add tool/generate_feast_notification_catalog_test.dart assets/data/feast_notification_catalog.json test/tool/generate_feast_notification_catalog_test.dart pubspec.yaml pubspec.lock
git commit -m "feat: export shared feast notification catalog"
```

Expected: generator prints event count/digest; test passes.

## Task 6: Add Android background schedule maintenance

**Files:**
- Create: `lib/data/services/feast_reminder_background_service.dart`
- Create: `test/data/services/feast_reminder_background_service_test.dart`
- Modify: `lib/main.dart`
- Modify: `pubspec.yaml`/`pubspec.lock`
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Add WorkManager and write a failing audit-decision test**

Run `flutter pub add workmanager`. Test a pure decision that repairs when schema, generation, timezone, or 30-day coverage differs and skips when all values are current.

- [ ] **Step 2: Verify the test fails**

Run: `flutter test test/data/services/feast_reminder_background_service_test.dart`

Expected: FAIL because the service is missing.

- [ ] **Step 3: Implement an idempotent callback dispatcher**

```dart
@pragma('vm:entry-point')
void feastReminderWorkmanagerDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return FeastReminderBackgroundService.instance.auditAndRepair();
  });
}
```

`auditAndRepair` exits successfully when disabled/permission-denied; otherwise initializes timezone/calendar/local notifications, applies the existing schedule policy, persists audit time, and uploads coverage only when online. Retryable initialization/scheduling failures return false.

- [ ] **Step 4: Register periodic and one-off repair work**

Initialize WorkManager in `main`. Register unique 24-hour periodic work named `feast-reminder-coverage-audit` with no network requirement. Enqueue unique replacement work after schema/app upgrade, startup timezone change, and settings changes.

- [ ] **Step 5: Verify and commit**

```powershell
flutter test test/data/services/feast_reminder_background_service_test.dart
flutter analyze lib/data/services/feast_reminder_background_service.dart lib/main.dart
flutter build apk --debug
git add lib/data/services/feast_reminder_background_service.dart test/data/services/feast_reminder_background_service_test.dart lib/main.dart pubspec.yaml pubspec.lock android/app/src/main/AndroidManifest.xml
git commit -m "feat: maintain reminder coverage in Android background"
```

Expected: tests/analyzer pass and APK builds with WorkManager manifest components.

## Task 7: Create Firebase registrations and add the messaging client

**Files:**
- Create: `android/app/google-services.json`
- Create: `ios/Runner/GoogleService-Info.plist`
- Create: `lib/firebase_options.dart`
- Create: `lib/data/services/feast_reminder_messaging_service.dart`
- Create: `test/data/services/feast_reminder_messaging_service_test.dart`
- Modify: `android/settings.gradle.kts`
- Modify: `android/app/build.gradle.kts`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `ios/Runner/AppDelegate.swift`
- Modify: `ios/Runner/Info.plist`
- Modify: `ios/Runner.xcodeproj/project.pbxproj`
- Modify: `lib/main.dart`
- Modify: `pubspec.yaml` and `pubspec.lock`

- [ ] **Step 1: Register Catholic Daily in Firebase project `elbiblio-fae32`**

```powershell
npm install --global firebase-tools
dart pub global activate flutterfire_cli
firebase login
flutterfire configure --project=elbiblio-fae32 --platforms=android,ios --android-package-name=com.elbiblio.catholicdaily --ios-bundle-id=com.elbiblio.catholicdaily --out=lib/firebase_options.dart
```

Expected: project contains Android/iOS apps for `com.elbiblio.catholicdaily`; generated options use `elbiblio-fae32`. If the interactive account lacks permission, use Firebase Management API with the server service account; its private key never enters the Flutter repository.

Verify the Catholic Daily iOS app entry has an APNs authentication key for the production Apple team. Reuse the project's existing Apple-team APNs key when present; if none is present, create one in Apple Developer Certificates, Identifiers & Profiles and upload the `.p8`, key ID, and team ID to this Firebase iOS app before claiming killed-state iOS delivery.

- [ ] **Step 2: Add dependencies and platform integration**

Run `flutter pub add firebase_core firebase_messaging`. Apply Google Services in Android Gradle, add default icon/color/channel metadata, enable iOS remote-notification background mode, and initialize `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` before messaging.

- [ ] **Step 3: Write failing remote-message tests**

Test a pure `RemoteFeastMessage` parser: v2 maps parse through `FeastReminderPayload.fromMap`, unrelated types are ignored, expired foreground messages are rejected, and taps retain celebration date.

- [ ] **Step 4: Implement Firebase handlers**

Register a top-level background handler before `runApp`. `FeastReminderMessagingService.initialize` subscribes to token refresh, foreground messages, opened messages, and initial messages. Foreground messages call `FeastReminderService.showRemoteReminder(payload)` to reuse tag/channel/copy. Background notification payloads are displayed by FCM; taps enter the existing reminder handler.

- [ ] **Step 5: Verify and commit**

```powershell
flutter test test/data/services/feast_reminder_messaging_service_test.dart
flutter analyze
flutter build apk --debug
git add android ios lib/firebase_options.dart lib/data/services/feast_reminder_messaging_service.dart test/data/services/feast_reminder_messaging_service_test.dart lib/main.dart pubspec.yaml pubspec.lock
git commit -m "feat: add Firebase feast reminder delivery client"
```

Expected: no “no matching client” build/runtime error.

## Task 8: Implement anonymous installation identity and coverage sync

**Files:**
- Create: `lib/data/services/notification_installation.dart`
- Create: `lib/data/services/notification_installation_store.dart`
- Create: `lib/data/services/notification_installation_api.dart`
- Create: `test/data/services/notification_installation_api_test.dart`
- Modify: `lib/data/services/feast_reminder_background_service.dart`
- Modify: `lib/data/services/feast_reminder_messaging_service.dart`
- Modify: `lib/ui/screens/settings_screen.dart`
- Modify: `pubspec.yaml` and `pubspec.lock`

- [ ] **Step 1: Add secure storage and failing wire-format tests**

Run `flutter pub add flutter_secure_storage`. Assert exact JSON fields: installation UUID, FCM token, platform, app version, locale, IANA timezone, liturgical region, permission state, enabled/rank/day-before/time, generation, and ISO coverage-through.

- [ ] **Step 2: Implement identity storage**

Generate UUIDv4-compatible bytes and a 32-byte secret with `Random.secure()`. Store both in `FlutterSecureStorage`. Store only token fingerprint, coverage, and sync timestamps in `SharedPreferences`. Never expose token/secret through `toString` or logs.

- [ ] **Step 3: Implement the injectable HTTP client**

Use `https://api.elbiblio.com/api/mobile/notification-installations`. Create sends ID/secret/state. Update/delete sends an `Authorization` value composed as `Installation {installation UUID}:{registration secret}`. Treat 200/201/204 as success; 401/404 trigger re-registration; 422 is non-retryable; 429/5xx/network errors are retryable.

- [ ] **Step 4: Connect lifecycle changes**

Initial/refreshed FCM token registers. Successful local scheduling uploads coverage. Settings changes sync permission/preferences and enqueue retry on network failure. Disabling reminders cancels feast reminder IDs and disables the installation.

- [ ] **Step 5: Test and commit**

```powershell
flutter test test/data/services/notification_installation_api_test.dart test/data/services/feast_reminder_background_service_test.dart test/data/services/feast_reminder_messaging_service_test.dart
flutter analyze lib/data/services/notification_installation*.dart lib/data/services/feast_reminder_*service.dart
git add lib/data/services/notification_installation*.dart lib/data/services/feast_reminder_background_service.dart lib/data/services/feast_reminder_messaging_service.dart lib/ui/screens/settings_screen.dart test/data/services pubspec.yaml pubspec.lock
git commit -m "feat: sync anonymous reminder coverage"
```

## Task 9: Add Laravel anonymous installation API

**Files:**
- Create: `/var/www/elb_api-notifications/database/migrations/2026_08_28_000001_create_notification_installations_table.php`
- Create: `/var/www/elb_api-notifications/app/Models/NotificationInstallation.php`
- Create: `/var/www/elb_api-notifications/app/Http/Middleware/AuthenticateNotificationInstallation.php`
- Create: `/var/www/elb_api-notifications/app/Http/Controllers/API/NotificationInstallationAPIController.php`
- Create: `/var/www/elb_api-notifications/tests/Feature/API/v1/NotificationInstallationAPITest.php`
- Modify: `/var/www/elb_api-notifications/bootstrap/app.php` and `routes/api.php`

- [ ] **Step 1: Write failing API tests**

Cover create 201, hashed secret/encrypted token, authenticated update 200, wrong secret 401, token rotation, disable 204, validation 422, and throttle 429. Use the exact Flutter wire fields.

- [ ] **Step 2: Verify failure**

```powershell
ssh -i C:\keys\bigbundle.pem -p 1145 patacee@178.79.176.19 "cd /var/www/elb_api-notifications && php artisan test tests/Feature/API/v1/NotificationInstallationAPITest.php"
```

Expected: FAIL because routes/classes/tables do not exist.

- [ ] **Step 3: Create table/model**

Use UUID identity plus hashed secret, encrypted token, unique HMAC token fingerprint, platform, app version, locale, timezone, region, permission, enabled/rank/day-before/hour/minute, generation, coverage, and last-seen/token-refreshed/disabled timestamps. Add casts and decrypt the token only at send time.

- [ ] **Step 4: Implement middleware and endpoints**

Validate create state, `Hash::make` the secret, `Crypt::encryptString` the token, and fingerprint with HMAC-SHA256 using `APP_KEY`. Parse `Authorization: Installation <uuid>:<secret>` for update/delete and verify with `Hash::check`. Rate-limit create to 10/minute/IP and updates to 60/minute/installation. Never return token/secret.

- [ ] **Step 5: Test and commit**

```bash
php artisan test tests/Feature/API/v1/NotificationInstallationAPITest.php
git add app/Http app/Models bootstrap/app.php routes/api.php database/migrations tests/Feature/API/v1/NotificationInstallationAPITest.php
git commit -m "feat: register anonymous notification installations"
```

Expected: PASS.

## Task 10: Import and validate the shared catalog in Laravel

**Files:**
- Create: `/var/www/elb_api-notifications/resources/data/feast_notification_catalog.json`
- Create: `/var/www/elb_api-notifications/app/Services/FeastNotificationCatalog.php`
- Create: `/var/www/elb_api-notifications/tests/Unit/FeastNotificationCatalogTest.php`

- [ ] **Step 1: Copy the exact artifact**

```powershell
scp -i C:\keys\bigbundle.pem -P 1145 assets/data/feast_notification_catalog.json patacee@178.79.176.19:/var/www/elb_api-notifications/resources/data/feast_notification_catalog.json
```

- [ ] **Step 2: Write failing catalog tests**

Assert schema/generation, recomputed SHA-256, date range, unique `(region,date,id)`, Nigeria Assumption on August 15, and lookup by region/date/minimum rank.

- [ ] **Step 3: Implement the catalog service**

Cache the parsed immutable data, verify digest/schema/generation before use, and expose exact signatures:

```php
public function eventsFor(string $region, CarbonImmutable $date, string $minimumRank): Collection;
public function generation(): string;
public function endDate(): CarbonImmutable;
```

Use rank weights Solemnity 3, Feast 2, Memorial/Obligatory Memorial 1, Optional Memorial 0.

- [ ] **Step 4: Test and commit**

```bash
php artisan test tests/Unit/FeastNotificationCatalogTest.php
git add resources/data/feast_notification_catalog.json app/Services/FeastNotificationCatalog.php tests/Unit/FeastNotificationCatalogTest.php
git commit -m "feat: load shared feast reminder catalog"
```

Expected: PASS and server artifact bytes match Flutter.

## Task 11: Implement idempotent, short-lived FCM fallback

**Files:**
- Create: `/var/www/elb_api-notifications/database/migrations/2026_08_28_000002_create_feast_notification_deliveries_table.php`
- Create: `/var/www/elb_api-notifications/app/Models/FeastNotificationDelivery.php`
- Create: `/var/www/elb_api-notifications/app/Services/FcmSendResult.php`
- Create: `/var/www/elb_api-notifications/app/Services/FeastReminderFallbackService.php`
- Create: `/var/www/elb_api-notifications/app/Console/Commands/SendFeastReminderFallbacks.php`
- Create: `/var/www/elb_api-notifications/tests/Feature/FeastReminderFallbackTest.php`
- Modify: `/var/www/elb_api-notifications/app/Services/PushNotificationService.php`
- Modify: `/var/www/elb_api-notifications/routes/console.php`
- Modify: `/var/www/elb_api-notifications/config/services.php`
- Modify: `/var/www/elb_api-notifications/.env.example`

- [ ] **Step 1: Write failing fallback tests**

Freeze time and prove: valid coverage skips; missing/expired coverage sends once; repeated runs do not resend; title has absolute date; TTL is the earlier of six hours/end-of-local-day; Android tag/collapse and APNs collapse equal occurrence key; disabled/denied/stale invalid installations skip; generation mismatch invalidates coverage; FCM `UNREGISTERED` disables the token.

- [ ] **Step 2: Verify failure**

Run: `php artisan test tests/Feature/FeastReminderFallbackTest.php`

Expected: FAIL because ledger/service/command are missing.

- [ ] **Step 3: Add delivery ledger**

Store installation, occurrence key, celebration date, planned time, expiry, status, channel, FCM message name/error, sent/failed times. Add unique `(notification_installation_id, occurrence_key, channel)`.

- [ ] **Step 4: Add typed FCM v1 sending**

Expose:

```php
public function sendFeastReminder(
    NotificationInstallation $installation,
    array $message
): FcmSendResult;
```

Build bounded Android/APNs payloads and classify invalid-token responses. Log only token fingerprints.

- [ ] **Step 5: Implement eligibility and command**

For each active installation, calculate local civil time, day/eve events, rank and time preference. Skip matching valid coverage. Reserve the unique ledger before send. Register `notifications:send-feast-fallbacks` every minute with `withoutOverlapping()`/`onOneServer()`, guarded by `FEAST_NOTIFICATION_FALLBACK_ENABLED=false`. Implement `--dry-run` (eligibility/status output with no writes/sends) and `--installation={uuid}` (single-installation acceptance targeting).

- [ ] **Step 6: Test regressions and commit**

```bash
php artisan test tests/Feature/FeastReminderFallbackTest.php tests/Feature/API/v1/PushNotificationFlowTest.php tests/Feature/API/v1/NotificationInstallationAPITest.php tests/Unit/FeastNotificationCatalogTest.php
git add app/Console app/Models app/Services config/services.php routes/console.php .env.example database/migrations tests
git commit -m "feat: send lease-controlled feast reminder fallback"
```

Expected: PASS; HTTP fakes assert bounded TTL and exact tag/collapse values.

## Task 12: Integrate, deploy disabled, and run end-to-end acceptance

**Files:**
- Modify only earlier-listed source/test files when acceptance finds defects.

- [ ] **Step 1: Run complete Flutter verification**

```powershell
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
flutter build apk --debug
```

Expected: all succeed.

- [ ] **Step 2: Run complete Laravel verification**

```bash
php artisan test
php artisan migrate:fresh --env=testing
php artisan route:list --path=mobile/notification-installations
php artisan schedule:list
```

Expected: suite passes; installation routes and disabled feast command are listed.

- [ ] **Step 3: Deploy server with fallback disabled**

Run these commands after the server branch tests pass:

```bash
git -C /var/www/elb_api-notifications push -u origin codex/durable-date-safe-notifications
git -C /var/www/elb_api merge --ff-only codex/durable-date-safe-notifications
git -C /var/www/elb_api push origin main
cd /var/www/elb_api
php artisan migrate --force
php artisan optimize:clear
php artisan config:cache
sudo supervisorctl restart elb
```

Before the restart, confirm the deployed environment either sets `FEAST_NOTIFICATION_FALLBACK_ENABLED=false` or omits it so the config default remains false. The pre-existing modified storage/language files must still appear unchanged in `git status --short` after the merge.

- [ ] **Step 4: Verify offline/killed/reboot delivery**

Install debug APK on an emulator/device. Schedule a near-term reminder, disable network, terminate the process without Force stop, and verify explicit-date delivery. Reboot and repeat. Capture alarm/job/notification/logcat evidence.

- [ ] **Step 5: Verify one fallback and duplicate suppression**

For a dedicated test installation, valid coverage must report `locally_covered`. Expire coverage and target that installation: exactly one FCM push should send, then the next run must report `duplicate_suppressed`. Disable the feature flag afterward.

- [ ] **Step 6: Verify cross-day grouping and tap date**

Deliver fixtures for two celebration dates, confirm separate dated groups, then tap the older notification on the next day and confirm navigation uses its payload date.

- [ ] **Step 7: Push Flutter branch for CI**

```powershell
git status --short
git log --oneline main..HEAD
git push -u origin codex/durable-date-safe-notifications
```

Expected: only intended tracked files are committed; unrelated untracked artifacts remain excluded.

## Final verification checklist

- [ ] No scheduled copy has a bare “Today.”
- [ ] Different celebration dates have different group keys.
- [ ] IDs/occurrence keys are deterministic across restarts.
- [ ] V1/legacy taps retain stored celebration dates.
- [ ] Android schedules beyond 64; iOS stays within 60.
- [ ] WorkManager audits offline from bundled data.
- [ ] Offline/process-killed/reboot acceptance passes.
- [ ] FCM registration requires no Elbiblio login.
- [ ] Valid coverage suppresses fallback duplicates.
- [ ] Fallback TTL cannot cross the local celebration date.
- [ ] Server kill switch stays off until targeted acceptance passes.
- [ ] No service-account private key, raw token, or installation secret is committed/logged.
