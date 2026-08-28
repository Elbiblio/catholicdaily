# Notification Safety Net and Reading Text-to-Speech Design

**Date:** 2026-08-28

**Status:** Approved for specification review

**Systems:** Catholic Daily Flutter app and the Elbiblio Laravel API

## Problem

The existing notification implementation makes reminder copy date-safe and
schedules a long local horizon, but its server coordination is based on a
coverage horizon. That horizon proves that the app attempted to schedule local
notifications; it does not prove that an individual notification reached the
user. Server fallback is therefore disabled, and enabling it under the current
model would either leave silent gaps or risk local/remote duplicates.

The readings UI also declares `flutter_tts` as a dependency but does not expose
speech controls. Users need a quick, unobtrusive way to listen to the exact
reading, psalm edition, or alternative currently displayed, plus an optional
way to continue through the appointed readings.

## Goals

1. Deliver each reminder while the app is open, backgrounded, or terminated.
2. Preserve offline delivery and tolerate a temporary server outage.
3. Prevent a server notification from appearing after its local safety copy.
4. Present at most one visible notification for an occurrence in normal
   operation.
5. Keep absolute dates, date-scoped grouping, and date-correct navigation.
6. Add one-tap speech through a small speaker icon on every reading surface.
7. Narrate the exact visible reading source and selected alternative.
8. Keep speech usable offline when an appropriate system voice is installed.

## Platform Boundaries

- iOS does not launch application code merely because a local notification was
  displayed while the app was terminated. A local-notification delivery ping
  therefore cannot be the cross-platform source of truth.
- Android explicit **Force stop** blocks alarms, background work, and FCM until
  the user manually launches the app again.
- iOS retains only a limited number of pending local notification requests.
  The app therefore maintains a conservative rolling safety-net window there;
  occurrences beyond that confirmed window remain eligible for on-time server
  delivery but cannot truthfully claim offline backup until the window is
  replenished.
- Delivery time can still be affected by device power state, denied permission,
  exact-alarm availability, Focus modes, or operating-system policy.
- Speech synthesis depends on an installed operating-system voice. Scripture
  text remains local, but a device without a suitable offline voice must offer
  an actionable voice-installation message rather than silently failing.

## Considered Notification Architectures

### Local-primary with a delivery acknowledgement

The local receiver would ping the server, and the server would push only when
the acknowledgement was absent. Android could support this with a first-party
native alarm receiver, but iOS does not execute app code when it displays a
terminated-app local notification. The design would therefore have asymmetric
guarantees and could still duplicate on iOS.

### Hardened coverage lease

The existing local-primary architecture could add lease expiry, schedule
fingerprints, per-occurrence scheduling records, and retries. This would make
coverage more accurate, but it would still confirm scheduling rather than
delivery and could not eliminate cross-channel duplicate races.

### Server-primary with a delayed local safety net — selected

The server attempts the on-time notification. The app independently schedules
the same occurrence as a local notification three minutes later. A server
notification is allowed to live for only two minutes, leaving a one-minute
non-overlap window in which the client cancels the local safety copy. If the
device is offline or the server path fails, the local notification fires after
three minutes. If the server notification cannot arrive before its two-minute
expiry, FCM/APNs discards it instead of delivering a stale duplicate later.

This architecture is uniform across Android and iOS, retains offline delivery,
and avoids relying on an unavailable iOS local-delivery callback.

## Notification Occurrence Contract

Every delivery path uses the existing deterministic occurrence key:

```text
feast:<region>:<YYYY-MM-DD>:<eve|on_day>:<celebration-id>
```

The notification payload schema advances to v3 and includes:

```json
{
  "schema": 3,
  "type": "feast_reminder",
  "occurrence_key": "feast:nigeria:2026-08-29:on_day:saint-id",
  "local_notification_id": 123456789,
  "celebration_date": "2026-08-29",
  "scheduled_for": "2026-08-29T07:00:00+01:00",
  "remote_expires_at": "2026-08-29T07:02:00+01:00",
  "local_safety_at": "2026-08-29T07:03:00+01:00",
  "timezone": "Africa/Lagos",
  "liturgical_region": "nigeria",
  "timing": "on_day",
  "title": "The Passion of Saint John the Baptist",
  "rank": "memorial",
  "saint_id": "saint-id",
  "schedule_generation": "calendar-data-version"
}
```

Schema v1 and v2 remain readable for existing pending notifications. New
schedules use v3. Title, body, expanded content, subtitle, group key, and tap
destination remain based on the absolute celebration date.

## Delivery Sequence

1. Flutter resolves an occurrence from the bundled liturgical calendar.
2. When local queue capacity permits, it schedules the safety notification for
   `scheduled_for + 3 minutes`.
3. It registers the occurrence with the API, including schedule generation,
   timezone, settings fingerprint, server time, remote expiry, local safety
   time, and whether that exact occurrence is confirmed as locally `armed`.
4. The Laravel scheduler attempts the remote notification at `scheduled_for`.
5. Temporary send failures may retry only inside the two-minute remote window.
6. A successfully received remote notification cancels the matching pending
   local notification before it is presented.
7. If no remote notification is received for a locally armed occurrence, the OS
   presents the local safety notification at the three-minute mark without
   needing network access or a running Flutter process.
8. On the next app launch or background audit, the client reconciles delivered,
   pending, expired, and superseded occurrences and uploads compact telemetry.

The server does not interpret an FCM message name as proof that the device
displayed a notification. It records only that FCM accepted the send. Client
receipt and user-open events are separate optional timestamps.

## Android Delivery and Deduplication

Android receives a high-priority, data-only FCM message through a first-party
`FirebaseMessagingService`. The service:

1. validates schema, expiry, occurrence key, and schedule generation;
2. cancels the matching local notification by stable ID and tag;
3. checks the native occurrence store for an already-presented occurrence;
4. atomically marks the occurrence as remotely presented; and
5. posts the date-safe notification through `NotificationManager`.

The native store is small, occurrence-keyed, and pruned after the celebration
date. It prevents repeated FCM messages or a late local path from posting twice.
Flutter receives tap payloads through the existing navigation contract.

The current boot receiver, WorkManager audit, exact/inexact scheduling policy,
and schedule journal remain. Android also adds repair triggers for timezone
changes, app replacement, boot completion, and exact-alarm permission changes.

## iOS Delivery and Deduplication

The server sends an APNs alert with `mutable-content: 1`, the occurrence key,
stable local notification identifier, and an APNs expiration matching
`remote_expires_at`.

A Notification Service Extension runs before background/terminated alert
presentation. It validates the payload and calls
`UNUserNotificationCenter.removePendingNotificationRequests` for the matching
local safety identifier, then completes presentation of the remote alert.

When the app is foregrounded, Firebase presentation remains disabled. Flutter
cancels the matching pending local request and renders exactly one notification
using the shared formatter. The remote window closes one minute before the
local safety trigger so APNs delivery and local delivery do not intentionally
race.

The extension target must be included in the archive, use the same notification
contract, and receive a valid distribution provisioning profile. Production
archive entitlements are verified in CI before upload.

## Laravel State and Retry Model

Add an occurrence-delivery table keyed by installation and occurrence key. It
stores:

- schedule generation, timezone, settings fingerprint, and platform;
- scheduled time, remote expiry, and local safety time;
- `armed_at`, first/last attempt, accepted, client-received, opened, expired,
  and reconciled timestamps;
- attempt count, last retryable/non-retryable error, and redacted FCM message
  identifier.

The state machine is:

```text
armed -> sending -> accepted
                 -> retryable_failure -> sending
                 -> terminal_failure
armed/sending/retryable_failure -> expired
accepted -> received/opened/reconciled
```

A unique `(installation_id, occurrence_key)` constraint prevents duplicate
occurrence records. A send reservation is not permanent: retryable failures
return to the queue while `now < remote_expires_at`. Terminal failures and
expired occurrences are never sent again.

The scheduler remains feature-flagged and supports an internal-installation
rollout before general enablement. Onboarding immediately registers and arms
occurrences rather than waiting for an app restart or periodic worker.

## Foreground and Reconciliation Rules

- A foreground remote receive first cancels the matching pending local safety
  notification, removes any already-delivered copy with that occurrence key,
  and then presents one date-safe notification.
- A notification tap records `opened_at` asynchronously and always navigates to
  `celebration_date`.
- App launch removes expired remote artifacts but does not remove a valid local
  notification merely because its date differs from the device's current date.
- Reconciliation is idempotent and never blocks opening the reading.
- Raw FCM tokens and installation secrets are never logged.

## Reading Text-to-Speech Architecture

Use an app-scoped narration controller behind a platform speech adapter:

- `SpeechEngine` defines initialization, speak, pause/resume, stop, completion,
  error, progress, language, voice, and rate operations.
- `FlutterTtsSpeechEngine` is the only class that imports `flutter_tts`.
- `ReadingNarrationComposer` converts the exact displayed reading into ordered
  speech segments.
- `ReadingNarrationQueueBuilder` selects one reading per logical liturgical
  slot and substitutes the currently selected alternative for its primary.
- `ReadingNarrationController` owns idle, loading, playing, paused, completed,
  unavailable, and error states across reading navigation.
- `NarrationPreferences` persists rate, language, and preferred installed voice.

No new state-management dependency is required. The controller is injected
through a lightweight app scope or explicit constructors, and tests use a fake
speech engine.

## Speech Composition

For the current reading, speech follows the visible devotional order:

1. reading position and reference;
2. visible incipit, when enabled;
3. responsorial response or Gospel acclamation, when present;
4. exact resolved body text for the selected edition.

Source labels, edition selector controls, duplicate headings, and unavailable
text placeholders are not spoken. Bible browse speaks the current chapter only.

“Read all appointed readings” uses the active `ReadingSession`, preserves
liturgical order, and reads one selected variant per logical slot. Easter Vigil
“after reading” psalm slots remain distinct. Changing a Bible version, psalm
edition, region, date, or selected alternative invalidates stale queued text.

## Unobtrusive Speech UI

- The primary affordance is a small icon-only speaker action in the reading
  app bar beside the bookmark icon. It has no fill, label, large container,
  floating placement, or persistent visual prominence.
- Expanded Mass-flow reading cards show the same icon as a trailing action.
- Tapping the speaker icon starts the current reading. While speaking, the icon
  changes to pause; while paused, it changes to resume.
- “Read all appointed readings” remains available through the existing overflow
  menu so the normal reading layout is unchanged.
- Only after playback starts, a slim dismissible mini-player appears at the
  bottom with previous section, play/pause, next section, stop, and speed.
- The mini-player never covers navigation controls or creates a side-by-side
  text view.
- The unused `ReadingDetailScreen`, if retained, uses the same icon and
  controller rather than creating a second speech implementation.

Although implemented with an accessible icon control internally, the visible
interface is the approved speaker icon—not a filled, outlined, text, or floating
button.

## Speech Lifecycle and Accessibility

- Speech never autoplays.
- Leaving the reading experience stops current-only playback.
- Previous/next navigation may preserve an intentional read-all queue.
- App backgrounding pauses speech; returning does not resume without user
  action. Detaching the app stops it.
- Installed offline voices are preferred. Network-required voices are not
  silently chosen when an offline voice exists.
- If no suitable voice is installed, the app explains how to install a system
  speech voice.
- Android 11+ declares the `android.intent.action.TTS_SERVICE` package query.
- On Android versions where reliable pause is unavailable, the UI exposes stop
  and restart rather than falsely claiming pause support.
- Speaker, pause, resume, and stop controls have semantic labels, tooltips, and
  at least a 48-by-48 logical touch target even though only the icon is visible.
- Screen-reader announcements cover loading, paused, completed, and error
  states; speech and screen-reader output never start automatically together.

True lock-screen media controls and continued narration after the app is
backgrounded are outside this change. They require a separate audio-session
architecture rather than `flutter_tts` alone.

## Test Strategy

### Flutter notification tests

- v3 payload parsing and backward compatibility with v1/v2.
- Remote expiry and local safety timestamps are deterministic.
- Foreground remote receipt cancels pending/delivered matching occurrences.
- Expired remotes never render.
- Onboarding immediately syncs registration and occurrences.
- Schedule repair responds to changed timezone, generation, settings, and exact
  alarm capability.

### Native notification tests

- Android service validates, cancels the local safety notification, claims the
  occurrence once, and suppresses repeats.
- Android local safety still fires with network disabled and Flutter terminated.
- iOS extension removes the matching pending request before completing the
  mutable remote notification.
- APNs/FCM expiration precedes the local safety trigger.
- Production archive contains the iOS extension and correct entitlements.

### Laravel tests

- Arming is authenticated, idempotent, and validates timing relationships.
- The scheduler sends at the intended local time only.
- Retryable failures retry inside the remote window.
- Terminal failures and expired occurrences never retry.
- One successful accepted send per installation and occurrence.
- Payloads contain matching occurrence key, local ID, expiry, absolute date,
  Android data-only priority, and iOS mutable-content fields.
- Kill switch and internal rollout filters work.

### Speech tests

- Composer ordering for normal readings, psalms, and Gospel acclamations.
- Exact selected Bible/psalm edition and alternative text is narrated.
- Read-all excludes unselected alternatives and preserves Easter Vigil slots.
- Controller state transitions, stale callback rejection, pause/resume/stop,
  next/previous section, lifecycle pause, and unavailable voice handling.
- Reading screen and Mass cards expose a semantically labelled speaker icon.
- No filled, floating, or text-labelled speech button is introduced.
- Mini-player appears only after playback begins and does not obscure reading
  navigation.

### End-to-end acceptance

1. Online, app terminated: remote arrives on time and the local safety copy is
   absent three minutes later.
2. Offline, app terminated: local safety copy arrives after three minutes;
   reconnecting later does not produce the expired remote.
3. Server send failure: local safety copy arrives.
4. App foregrounded: one notification is rendered and its local backup is
   cancelled.
5. Duplicate remote injection: only one occurrence remains visible.
6. Reboot before delivery: local safety copy survives and the remote can still
   cancel it.
7. Tapping the speaker icon reads the displayed selection offline, and changing
   edition or alternative updates the spoken text.
8. Read-all traverses the appointed reading sequence once, with working compact
   controls and no intrusive idle-state UI.

## Rollout

1. Deploy backward-compatible occurrence endpoints and tables with sending off.
2. Ship the app with v3 local safety scheduling, native cancellation handlers,
   iOS extension, immediate registration, and speech controls.
3. Verify production Android and iOS killed/offline acceptance on internal
   installations.
4. Enable server delivery only for internal installations and inspect duplicate,
   expiry, retry, and local-safety metrics.
5. Expand gradually, retaining an immediate server kill switch. Local safety
   notifications remain active if the server path is disabled.

## Success Criteria

- An online notification normally appears at the selected time and never again
  as a local duplicate.
- An offline or server-failed device still receives every locally armed
  notification within three minutes while the app is terminated.
- An expired remote notification cannot appear after the local safety copy.
- Date labels and tap navigation remain accurate across delayed and grouped
  notifications.
- Every reading surface exposes a small speaker icon with one-tap current
  reading speech.
- Spoken content always matches the visible selected reading and edition.
- All Flutter, Android, iOS, Laravel, archive-entitlement, and end-to-end tests
  pass before server sending is enabled generally.
