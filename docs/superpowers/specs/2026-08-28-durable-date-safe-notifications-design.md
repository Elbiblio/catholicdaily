# Durable, Date-Safe Notifications Design

**Date:** 2026-08-28

**Status:** Approved for implementation

**Systems:** Catholic Daily Flutter app and `/var/www/elb_api` Laravel API

## Problem

Feast reminders are scheduled in advance with copy such as “Today” or “Tomorrow.” Android can deliver, retain, or group that immutable copy after its intended day, making an old notification appear current. All reminders also share one Android group key, so notifications for different liturgical dates can be batched together without a reliable visible date.

The app currently uses OS-owned local scheduled notifications. This already supports delivery while the process is swiped away or terminated, while the device is offline, and after reboot through the notification plugin's boot receiver. It does not currently use Firebase Cloud Messaging (FCM), has a universal 64-notification cap, and replenishes the rolling schedule mainly when the app opens. Consequently, long periods without opening the app can exhaust scheduled coverage. Android's explicit **Force stop** remains an operating-system boundary: both alarms and FCM are blocked until the user launches the app again.

## Goals

1. A delivered notification must remain factually correct even if it is delayed or viewed days later.
2. Notifications for different celebration dates must never be grouped as though they belong to the same day.
3. Routine reminders must work without network access and while the app process is not running.
4. Reboot, timezone changes, app upgrades, and long periods without launching the app must not silently end reminder coverage.
5. Server push must provide controlled fallback and replenishment without routinely duplicating local reminders.
6. Notification taps must always open the intended liturgical date, not the device's current date.
7. Registration must work for Catholic Daily installations that are not signed into an Elbiblio account.

## Non-goals and Platform Boundary

- The design does not claim delivery after the user explicitly selects Android **Force stop**. Android prevents the app's alarms, jobs, and FCM receiver from running until a subsequent manual launch.
- No notification system can guarantee an exact delivery time when the device is powered off, notification permission is denied, the platform suppresses alarms, or iOS decides not to run background work.
- Server fallback is not a replacement for local scheduling. FCM cannot deliver while a device has no network connection.
- The implementation will not request unrestricted battery-optimization exemption automatically. Exact alarms, reboot recovery, and WorkManager will be used within platform and store policies; the settings UI may explain manufacturer battery restrictions.

## Evidence and Existing Infrastructure

The publicly distributed Oremus Android package uses the same hybrid pattern selected here:

- `SCHEDULE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`, and `POST_NOTIFICATIONS` permissions;
- a timing-push broadcast receiver that handles boot and exact-alarm permission changes;
- a `FirebaseMessagingService` registered for `com.google.firebase.MESSAGING_EVENT`;
- AndroidX WorkManager services and rescheduling receivers.

Catholic Daily already has exact/inexact local scheduling, boot receivers, and a rolling reminder generator. The Laravel server already has FCM HTTP v1 credential support, device-token storage for authenticated users, and a cron-driven Laravel scheduler that runs every minute. The missing pieces are the Catholic Daily Firebase client, anonymous installation registration, background coverage maintenance, date-safe content, and lease-based fallback coordination.

## Selected Architecture

Use a **hybrid local-primary, server-fallback** architecture.

### Delivery flow

1. The app computes reminder occurrences from its bundled liturgical calendar.
2. It schedules local OS notifications and records a deterministic occurrence key for each one.
3. It uploads a coverage lease to the Laravel API when online: the installation, timezone, preferences, schedule generation, and the last date through which every eligible occurrence has been scheduled locally.
4. Android WorkManager periodically audits and replenishes local coverage from bundled data, even when the UI process has not been opened. App launch, reboot/app replacement, timezone change, permission change, and preference change also trigger an audit.
5. The Laravel scheduler calculates due reminders. It sends FCM only when the device is eligible and its confirmed local coverage does not include that occurrence, or when a server-side calendar correction explicitly invalidates a prior generation.
6. Every local and remote notification carries the same date-specific occurrence key and absolute celebration date.

This preserves genuine offline delivery while allowing the server to cover expired or invalid schedules.

## Date-Safe Notification Contract

Relative words are prohibited in immutable scheduled notification copy. Titles, expanded text, subtitles, and group summaries must use an absolute localized date.

Example:

```text
Saturday, 29 August — Memorial
The Passion of Saint John the Baptist
```

An eve reminder may say:

```text
Tomorrow's celebration · Saturday, 29 August
The Passion of Saint John the Baptist
```

The word “Tomorrow” is acceptable only when the absolute date is present in the same visible notification. “Today” will not be used in scheduled copy.

### Grouping

- Android group key: `feast_reminders:<celebration-date>`
- Group summary: `<localized absolute date> · <count> celebrations`
- Sort key begins with the celebration date and scheduled time.
- Notifications from different celebration dates therefore occupy separate groups.

### Payload schema v2

```json
{
  "schema": 2,
  "type": "feast_reminder",
  "occurrence_key": "feast:nigeria:2026-08-29:on_day:saint-id",
  "celebration_date": "2026-08-29",
  "scheduled_for": "2026-08-29T07:00:00+01:00",
  "timezone": "Africa/Lagos",
  "liturgical_region": "nigeria",
  "timing": "on_day",
  "title": "The Passion of Saint John the Baptist",
  "rank": "memorial",
  "saint_id": "...",
  "schedule_generation": "calendar-data-version"
}
```

Schema v1 payloads remain readable. When their celebration date is present, navigation uses it. Malformed or date-less payloads fall back safely to the calendar home rather than pretending the current day is the intended day.

## Deterministic Identity and Duplicate Control

- `occurrence_key` is a canonical string built from notification type, liturgical region, celebration date, timing, and stable celebration identity.
- The local numeric notification ID is a stable 31-bit digest of `occurrence_key`; Dart's runtime `hashCode` is not used.
- Android local notifications use the occurrence key as their tag.
- FCM uses the same value as its Android notification tag and APNs collapse identifier.
- The server enforces a unique delivery record per `(installation_id, occurrence_key, channel)` and will not enqueue repeated fallback deliveries.
- Normal FCM fallback is suppressed whenever the uploaded local-coverage lease includes the occurrence.
- A short FCM lifetime expires at the earlier of six hours after the scheduled time or the end of the celebration's local calendar date. Absolute-date copy remains correct even if the notification arrives late within that window.

## Flutter Client Changes

### Local scheduling

- Extract notification rendering into a pure formatter accepting celebration date, scheduled time, timezone, rank, title, and timing.
- Replace every hard-coded `Today`/`Tomorrow` title, body, subtitle, and summary with the date-safe contract.
- Generate deterministic IDs and date-scoped group keys.
- Extend `FeastReminderPayload` to schema v2 with backward-compatible parsing.
- Keep exact-while-idle scheduling when permission is available and inexact-while-idle fallback otherwise.
- Remove the universal 64 cap on Android. Schedule the configured rolling horizon there.
- Retain a conservative iOS pending-notification budget (target 60, leaving room for non-feast notifications) and define coverage only through the last completely scheduled occurrence.

### Background maintenance

- Add Android WorkManager with a periodic coverage-audit task and a one-off repair task.
- The task initializes only the services needed for calendar resolution and scheduling, uses bundled/offline data, and is idempotent.
- Trigger one-off repair after app upgrade, reboot-reschedule detection, timezone change, exact-alarm permission change, and reminder-preference change where platform hooks permit.
- Persist scheduling state transactionally: schema version, generation, timezone, scheduled occurrence keys, and `coverage_through`.

### Firebase Messaging

- Add Firebase Core and Firebase Messaging using the Catholic Daily Firebase application configuration associated with the server's FCM project.
- Register the current token and refresh it whenever Firebase rotates it.
- Handle foreground messages with the local notification renderer so appearance and payload behavior match scheduled reminders.
- Allow background notification delivery through FCM using the shared occurrence key and date-safe server copy.
- On notification tap, parse payload v2 and navigate to `celebration_date`.

### Installation identity

- Generate a random, non-personal installation UUID and a separate random registration secret on first run.
- Store the secret in platform-secure storage.
- Do not send advertising identifiers, contacts, or unrelated account data.
- If the user later signs in, the same installation may additionally be associated with their account without changing its notification identity.

## Laravel Server Changes

### Data model

Create notification-installation storage separate from the existing authenticated `device_tokens` table. Minimum fields:

- installation UUID and hashed registration secret;
- FCM token, platform, app version, locale, timezone;
- notification permission state, liturgical region, and reminder preferences;
- schedule schema/generation and `local_coverage_through`;
- last seen, token refreshed, and disabled timestamps.

Create a delivery ledger with a unique key over installation and occurrence key, status, channel, planned time, FCM message name, and error/expiry metadata.

### API

- `POST /api/mobile/notification-installations` creates or rotates an anonymous installation registration.
- `PUT /api/mobile/notification-installations/{installation}` updates token, timezone, liturgical region, preferences, and coverage; it requires proof of the per-installation secret.
- `DELETE .../{installation}` disables the token when notifications are turned off or the installation is retired.
- Endpoints are narrowly rate-limited, validate token/platform/timezone/app-version fields, never return stored tokens, and log only redacted token identifiers.

### Scheduling

- Add a Laravel command that runs every minute without overlapping.
- Resolve due liturgical reminders per installation timezone and preference.
- Skip an occurrence when confirmed local coverage includes it.
- Skip disabled, permission-denied, invalid, or expired installations.
- Enqueue one fallback push per eligible occurrence and rely on the unique delivery ledger for idempotency.
- Use FCM HTTP v1 with the existing service-account infrastructure.
- Set Android `tag`, collapse key, channel, priority, and bounded TTL; set matching APNs collapse ID and expiration.
- Disable invalid/unregistered tokens based on FCM responses.

The existing 28-day FCM TTL is not used for liturgical reminders because it permits severely outdated delivery.

## Calendar Source Consistency

Local and server scheduling must agree on a `schedule_generation` identifier. Initially, the server may consume a generated compact reminder-occurrence artifact, including each supported liturgical region, exported from the same validated calendar resolver used by Flutter. A release publishes the artifact and its digest. If the server generation differs from a device's reported generation, the server treats local coverage as unconfirmed for corrected occurrences and may send a bounded fallback.

The server must not independently reimplement feast precedence rules in PHP.

## Failure Handling

- **Offline at scheduled time:** the local alarm delivers. FCM expires if it cannot arrive within its bounded lifetime.
- **App UI process killed/swiped away:** OS alarm or FCM notification delivery continues.
- **Device rebooted:** scheduled notification boot receiver restores pending alarms; WorkManager audits coverage afterward.
- **App unopened beyond local horizon:** WorkManager extends Android coverage; server fallback covers missing/expired leases when network is available.
- **Timezone changed:** app rebuilds local occurrences and updates the lease; server only evaluates using the last confirmed timezone and expires date-bound pushes quickly.
- **Token rotated:** Flutter sends the new token; server disables the prior token for that installation.
- **Permission denied:** local scheduling and server push are disabled for the installation until permission is granted.
- **Explicit Android Force stop:** delivery resumes only after the next manual app launch, at which point a full audit, token refresh, stale cleanup, and lease update run.

## Test Strategy

### Flutter unit tests

- Scheduled copy never contains a bare `Today` and always displays the celebration date.
- Eve copy includes the absolute target date.
- Group keys differ across dates and match within a date.
- Occurrence keys and numeric IDs are stable and collision-checked over the complete bundled calendar horizon.
- Payload v1 and v2 parse correctly; tap navigation uses the payload date.
- Coverage calculation stops before the first unscheduled eligible occurrence, especially at the iOS cap.
- Repeated scheduling is idempotent.

### Flutter integration/platform tests

- Schedule a near-term notification, terminate the process, and verify delivery.
- Disable network, terminate the process, and verify local delivery.
- Reboot the emulator and verify pending delivery.
- Change timezone and verify the old occurrence is replaced rather than duplicated.
- Deliver a foreground FCM test and verify identical date-safe rendering.
- Rotate an FCM token and verify registration update.

### Laravel tests

- Anonymous installation creation, authenticated update, rotation, throttling, and disable flow.
- No fallback inside valid local coverage.
- One fallback outside coverage and no duplicate on repeated scheduler runs.
- Per-timezone due-time calculations, date-safe content, short TTL, and collapse/tag fields.
- Invalid token responses disable the installation.
- No push after local-date expiry.
- Calendar-generation mismatch behavior.

### End-to-end acceptance

Use a real Android emulator/device and the production-like Laravel queue/scheduler:

1. Register Catholic Daily and confirm a redacted installation record.
2. Verify a local reminder while offline and process-terminated.
3. Expire the test coverage lease and verify one FCM fallback while process-terminated.
4. Restore valid coverage and verify the server does not send a duplicate.
5. Create reminders spanning two dates and verify separate groups with explicit dates.
6. Reboot before delivery and verify the reminder survives.

## Rollout and Observability

1. Deploy backward-compatible server tables/endpoints and scheduler disabled by feature flag.
2. Release the Flutter client with date-safe local notifications, WorkManager, registration, and coverage reporting.
3. Validate registration and local coverage telemetry without sending fallback pushes.
4. Enable server fallback for internal/test installations.
5. Expand gradually while monitoring enqueue, sent, invalid-token, expired, locally-covered, and duplicate-suppressed counts.
6. Keep a server kill switch for feast fallback delivery without disabling local reminders.

Logs and metrics must use installation UUIDs and redacted token fingerprints, never raw FCM tokens or registration secrets.

## Success Criteria

- No notification can falsely label an old celebration as “Today.”
- Cross-day reminders are visibly dated and grouped separately.
- Offline/process-killed/rebooted Android acceptance tests deliver the locally scheduled reminder.
- An expired local coverage lease produces exactly one bounded FCM fallback when the device is online.
- A valid local coverage lease produces no FCM duplicate.
- Notification taps open the celebration date carried in the payload.
- All new Flutter and Laravel tests pass, and production credentials remain server-side only.
