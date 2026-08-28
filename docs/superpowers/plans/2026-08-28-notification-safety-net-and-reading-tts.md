# Notification Safety Net and Reading TTS Implementation Plan

> **Execution rule:** Implement test-first, keep Flutter and Laravel commits
> focused, and do not enable general server sending until killed/offline and
> duplicate-suppression acceptance tests pass.

**Goal:** Add an on-time server notification with a three-minute local offline
safety net, bounded two-minute remote lifetime, cross-platform cancellation,
and unobtrusive icon-only reading narration.

**Architecture:** Flutter schedules and journals delayed local safety copies and
arms deterministic occurrences with Laravel. Laravel sends during a two-minute
window. Android handles high-priority data messages in the registered Flutter
background isolate and iOS uses a Notification Service Extension; both cancel
the matching local safety copy before presenting the remote. An app-scoped TTS
controller reads the exact displayed text through an icon-only speaker action.

**Repositories:**

- Flutter: `C:\dev\catholicdaily-flutter\.worktrees\durable-date-safe-notifications`
- Laravel: `C:\dev\elb_api-notifications`

**Tech stack:** Flutter/Dart, `flutter_local_notifications`, Firebase Messaging,
`flutter_tts`, Android Kotlin, iOS Swift/UserNotifications, Laravel/PHP, MySQL.

---

## Task 1: Extend the notification contract to schema v3

**Flutter files:**

- Modify `lib/data/services/feast_reminder_payload.dart`
- Modify `lib/data/services/feast_reminder_notification_contract.dart`
- Modify `test/data/services/feast_reminder_payload_test.dart`
- Modify `test/data/services/feast_reminder_notification_contract_test.dart`
- Modify `test/fixtures/feast_fallback_contract_v2.json` only if a new v3
  fixture is added alongside it; do not delete the v2 compatibility fixture

**Steps:**

1. Add failing tests for `remoteExpiresAt`, `localSafetyAt`, stable local ID,
   two-minute/three-minute timing, and v1/v2 backward parsing.
2. Run:

   ```powershell
   flutter test test/data/services/feast_reminder_payload_test.dart test/data/services/feast_reminder_notification_contract_test.dart
   ```

   Expected: new assertions fail.
3. Add schema v3 fields while retaining legacy parsing.
4. Add pure helpers that derive:
   - `remote_expires_at = scheduled_for + 2 minutes`
   - `local_safety_at = scheduled_for + 3 minutes`
   - the existing stable FNV-1a notification ID.
5. Reject payloads where expiry is after safety time, safety time is not after
   scheduled time, or identity/date fields disagree.
6. Re-run the focused tests and commit:

   ```powershell
   git add lib/data/services/feast_reminder_payload.dart lib/data/services/feast_reminder_notification_contract.dart test/data/services/feast_reminder_payload_test.dart test/data/services/feast_reminder_notification_contract_test.dart test/fixtures
   git commit -m "feat: add notification safety-net contract"
   ```

## Task 2: Schedule delayed local safety notifications

**Files:**

- Modify `lib/data/services/feast_reminder_service.dart`
- Modify `lib/data/services/feast_reminder_preferences.dart`
- Modify `lib/data/services/feast_reminder_schedule_capacity.dart`
- Modify `lib/data/services/feast_reminder_schedule_policy.dart`
- Modify `test/data/services/feast_reminder_schedule_capacity_test.dart`
- Modify `test/data/services/feast_reminder_schedule_policy_test.dart`
- Add `test/data/services/feast_reminder_safety_schedule_test.dart`

**Steps:**

1. Add failing pure tests proving the intended server time remains unchanged
   while the OS local trigger is exactly three minutes later.
2. Test that iOS coverage stops at the last fully armed celebration date and
   reports farther occurrences as server-only.
3. Advance the schedule schema version and persist v3 occurrence metadata in
   the crash journal.
4. Change feast `zonedSchedule` calls to use `localSafetyAt`, while payload copy
   and navigation continue to use the celebration date and intended time.
5. Preserve exact/inexact Android policy, iOS capacity, stable IDs/tags, boot
   restoration, and atomic schedule completion.
6. Add helpers to cancel one occurrence by ID/tag and to query whether it is
   still pending.
7. Run the focused schedule tests and commit:

   ```powershell
   flutter test test/data/services/feast_reminder_schedule_capacity_test.dart test/data/services/feast_reminder_schedule_policy_test.dart test/data/services/feast_reminder_safety_schedule_test.dart
   git add lib/data/services/feast_reminder_service.dart lib/data/services/feast_reminder_preferences.dart lib/data/services/feast_reminder_schedule_capacity.dart lib/data/services/feast_reminder_schedule_policy.dart test/data/services
   git commit -m "feat: schedule delayed local notification safety net"
   ```

## Task 3: Add occurrence arming and client reconciliation

**Files:**

- Add `lib/data/services/notification_occurrence.dart`
- Add `lib/data/services/notification_occurrence_api.dart`
- Add `lib/data/services/notification_occurrence_store.dart`
- Add `lib/data/services/notification_occurrence_sync_service.dart`
- Modify `lib/data/services/notification_installation_api.dart`
- Modify `lib/data/services/notification_installation_sync_service.dart`
- Modify `lib/data/services/feast_reminder_background_service.dart`
- Modify `lib/ui/screens/onboarding_screen.dart`
- Modify `lib/ui/screens/feast_reminder_settings_sheet.dart`
- Add tests under `test/data/services/notification_occurrence_*_test.dart`
- Extend `test/data/services/feast_reminder_background_service_test.dart`

**Steps:**

1. Add failing tests for authenticated, idempotent occurrence arming, batching,
   retry classification, locally armed versus server-only state, and pruning.
2. Define a compact batch request with occurrence key, stable local ID,
   scheduled/expiry/safety timestamps, platform, generation, timezone,
   configuration fingerprint, and `local_armed`.
3. Store unsynchronized occurrence state locally without storing raw FCM tokens
   or duplicating the installation secret outside secure storage.
4. Sync immediately after onboarding and every successful reschedule; enqueue a
   repair for retryable network failures.
5. Reconcile opened, received, expired, and no-longer-pending occurrences during
   startup/background audits without blocking UI launch.
6. Add Android WorkManager repair inputs for timezone and exact-alarm changes;
   keep work idempotent.
7. Run focused tests and commit:

   ```powershell
   flutter test test/data/services/notification_occurrence_api_test.dart test/data/services/notification_occurrence_store_test.dart test/data/services/notification_occurrence_sync_service_test.dart test/data/services/feast_reminder_background_service_test.dart
   git add lib/data/services lib/ui/screens/onboarding_screen.dart lib/ui/screens/feast_reminder_settings_sheet.dart test/data/services
   git commit -m "feat: arm and reconcile notification occurrences"
   ```

## Task 4: Cancel local safety copies on Android remote receipt

**Files:**

- Modify `lib/data/services/feast_reminder_messaging_service.dart`
- Modify `lib/data/services/feast_reminder_service.dart`
- Modify `lib/main.dart`
- Modify `android/app/src/main/AndroidManifest.xml`
- Add `android/app/src/main/kotlin/com/elbiblio/catholicdaily/FeastReminderOccurrenceStore.kt`
- Add native tests under `android/app/src/test/kotlin/com/elbiblio/catholicdaily/`
- Extend `test/data/services/feast_reminder_messaging_service_test.dart`

**Steps:**

1. Add failing Dart tests for background/foreground remote processing order:
   validate -> expiry check -> cancel pending local -> deduplicate -> show once.
2. Add a minimal native occurrence store keyed by occurrence key and pruned by
   celebration date. Use it only for durable duplicate claims; keep content and
   calendar rules in Dart/shared payloads.
3. Convert Android server messages to high-priority data-only messages so the
   background handler controls presentation instead of automatic double-posting.
4. In the background handler, initialize notifications, cancel ID/tag, reject
   expired or already-claimed occurrences, show one date-safe notification, and
   queue a receipt reconciliation.
5. In foreground handling, remove any delivered matching copy, cancel the
   pending safety alarm, then render exactly one notification.
6. Add manifest declarations needed by the native store/receivers and explicit
   repair broadcasts for timezone/exact-alarm changes.
7. Run Dart and Android unit tests:

   ```powershell
   flutter test test/data/services/feast_reminder_messaging_service_test.dart
   .\android\gradlew.bat -p android testDebugUnitTest
   ```

8. Commit the Android path.

## Task 5: Add the iOS Notification Service Extension

**Files:**

- Add `ios/FeastReminderNotificationService/NotificationService.swift`
- Add `ios/FeastReminderNotificationService/Info.plist`
- Modify `ios/Runner.xcodeproj/project.pbxproj`
- Modify `ios/Runner/Info.plist`
- Modify `ios/Podfile` if target pod inheritance is required
- Modify `.github/workflows/mobile-ci.yml`
- Add a fixture-driven Swift test or CI validation script under `tool/`

**Steps:**

1. Add a failing fixture validation test proving an iOS v3 payload includes
   `mutable-content`, occurrence key, stable local identifier, and expiration.
2. Add the extension target embedded in Runner with iOS 15 minimum deployment.
3. In `didReceive`, validate v3 timing/identity, remove the pending local request
   by identifier, and always call the content handler. Preserve original content
   on malformed input or timeout.
4. Keep foreground handling in Flutter because the extension is for remote alert
   presentation outside the active app.
5. Update CI to provision/sign both Runner and the extension, inspect archive
   entitlements, and fail if the `.appex` is absent.
6. On macOS CI, run `pod install`, build the extension, and execute archive
   validation. Commit only after the target appears in the archive.

## Task 6: Add Laravel occurrence APIs and state

**Laravel files:**

- Add a migration for notification occurrences or evolve the existing delivery
  ledger without deleting historical rows
- Add/modify `app/Models/NotificationOccurrence.php`
- Add `app/Http/Controllers/API/NotificationOccurrenceAPIController.php`
- Add request validation/authentication through the existing installation
  middleware
- Modify `routes/api.php`
- Add `tests/Feature/API/v1/NotificationOccurrenceAPITest.php`

**Steps:**

1. Write failing API tests for authenticated batch arming, idempotency, timing
   validation, settings/generation context, `local_armed`, and reconciliation.
2. Add a unique `(notification_installation_id, occurrence_key)` index.
3. Store scheduled, expiry, safety, arm, receive, open, reconcile, attempt, and
   error state. Keep tokens encrypted in the installation model.
4. Add a batched `PUT` endpoint under
   `/api/mobile/notification-installations/{installation}/occurrences` and a
   compact reconciliation endpoint.
5. Rate-limit and cap batch size; return per-item validation outcomes without
   exposing secrets or raw tokens.
6. Run:

   ```powershell
   php artisan test tests/Feature/API/v1/NotificationOccurrenceAPITest.php tests/Feature/API/v1/NotificationInstallationAPITest.php
   ```

7. Commit in `C:\dev\elb_api-notifications`.

## Task 7: Replace lease suppression with bounded server-primary sending

**Laravel files:**

- Modify `app/Services/FeastReminderFallbackService.php` or rename it to a
  server-primary occurrence service while preserving a compatibility command
- Modify `app/Console/Commands/SendFeastReminderFallbacks.php`
- Modify `app/Services/PushNotificationService.php`
- Modify `routes/console.php`
- Modify `config/services.php`
- Modify `tests/Feature/FeastReminderFallbackTest.php`
- Add platform payload fixtures under `tests/Fixtures/`

**Steps:**

1. Add failing tests for due `armed` occurrences, server-only occurrences,
   two-minute expiry, retries, terminal errors, expiry, one accepted send, and
   platform-specific payloads.
2. Stop suppressing sends merely because `coverage_through` includes a date.
3. Claim due rows transactionally with `lockForUpdate`/skip-locked behavior so
   overlapping workers cannot send twice.
4. Permit retryable failures only while `now < remote_expires_at`; do not let a
   failed reservation permanently suppress later attempts.
5. Send Android high-priority data-only payloads. Send iOS alerts with
   `mutable-content: 1`, matching APNs expiration/collapse ID, and local ID.
6. Record FCM acceptance separately from client receipt/open reconciliation.
7. Retain disabled-by-default and internal-installation rollout switches.
8. Run all notification server tests and commit.

## Task 8: Build the pure narration layer test-first

**Flutter files:**

- Add `lib/data/services/speech_engine.dart`
- Add `lib/data/services/flutter_tts_speech_engine.dart`
- Add `lib/data/services/reading_narration_composer.dart`
- Add `lib/data/services/reading_narration_queue_builder.dart`
- Add `lib/data/services/reading_narration_controller.dart`
- Add `lib/data/services/narration_preferences.dart`
- Add corresponding tests under `test/data/services/`

**Steps:**

1. Add pure failing tests for reading/reference/incipit/body order, psalm
   response, Gospel acclamation, duplicate suppression, and unavailable text.
2. Add queue tests for primary-only slots, selected-alternative replacement,
   Easter Vigil “after reading” slots, and current Bible chapter behavior.
3. Add controller tests using `FakeSpeechEngine` for state transitions,
   completion, stale callback rejection, pause/resume/stop, next/previous,
   lifecycle pause, errors, and unavailable voices.
4. Implement the engine adapter as the only `flutter_tts` import. Configure
   completion/error/progress handlers once and prefer installed offline voices.
5. Persist speech rate/language/voice through `NarrationPreferences`.
6. Add the Android 11 `android.intent.action.TTS_SERVICE` query to the manifest.
7. Run all narration tests and commit.

## Task 9: Add the unobtrusive speaker-icon UI

**Flutter files:**

- Add `lib/ui/widgets/read_aloud_icon.dart`
- Add `lib/ui/widgets/narration_mini_player.dart`
- Modify `lib/ui/screens/reading_screen.dart`
- Modify `lib/ui/screens/mass_flow_screen.dart`
- Modify `lib/ui/screens/reading_detail_screen.dart` if it remains reachable
- Modify `lib/ui/screens/home_screen.dart` to provide active session text/queue
- Extend `test/ui/screens/reading_screen_lifecycle_test.dart`
- Add `test/ui/widgets/read_aloud_icon_test.dart`
- Add/update Mass-flow widget tests

**Steps:**

1. Add failing widget tests proving the idle UI contains one semantically
   labelled speaker icon and no filled, outlined, floating, or text speech
   button.
2. Add the icon beside bookmark in the reading app bar and as a trailing action
   on expanded Mass-flow reading cards.
3. Map idle/playing/paused state to speaker/pause/resume icons with tooltips and
   48-by-48 semantic hit targets while keeping the visible glyph small.
4. Add “Read all appointed readings” to the existing overflow menu.
5. Show the slim dismissible mini-player only after playback starts; include
   previous, play/pause, next, stop, and speed without covering reading
   navigation.
6. Invalidate/recompose narration after edition, region, date, or alternative
   changes. Stop current-only playback when leaving the reading experience;
   preserve deliberate read-all navigation.
7. Run focused widget/lifecycle tests and commit.

## Task 10: Full verification and production rollout gate

**Flutter verification:**

```powershell
flutter analyze
flutter test
.\android\gradlew.bat -p android testDebugUnitTest
flutter build apk --debug
flutter build windows --debug
```

**Laravel verification:**

```powershell
php artisan test
php artisan route:list --path=mobile/notification-installations
php artisan schedule:list
```

**Acceptance matrix:**

1. Android online/terminated: remote on time, no local at +3 minutes.
2. Android offline/terminated: local at +3 minutes, no remote after reconnect.
3. Android reboot before trigger: safety copy survives.
4. Android foreground: one visible notification and cancelled backup.
5. iOS online/terminated on TestFlight build: extension cancels backup.
6. iOS offline/terminated: local safety copy appears for an armed occurrence.
7. Duplicate remote injection: only one occurrence remains visible.
8. Speaker icon reads the selected edition offline on Android, iOS, and Windows.
9. Read-all uses one selected variant per slot and compact controls.

Do not enable the server generally if any killed/offline, expiry, duplicate, or
archive-extension check fails. Keep the server kill switch off during the first
client release, then enable internal installations and inspect metrics.

## Task 11: Version, commit, push, and CI verification

1. Confirm both worktrees contain only intentional changes; preserve the
   pre-existing line-ending-only Windows generated-header modification.
2. Bump `pubspec.yaml` once, after implementation and verification.
3. Update release notes if the repository uses them.
4. Commit Flutter and Laravel changes separately with focused history.
5. Push the Laravel main branch only after production-safe migrations and tests
   pass; deploy migrations/code with sending disabled.
6. Push the Flutter release branch/main according to the established release
   flow to trigger Android, iOS, and Windows CI.
7. Wait for CI completion and verify:
   - Play upload accepted;
   - TestFlight archive contains the notification extension and correct push
     entitlements;
   - Windows artifact succeeds;
   - no general server sends occur before the client rollout gate is opened.
