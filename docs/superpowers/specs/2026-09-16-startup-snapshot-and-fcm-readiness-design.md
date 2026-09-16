# Startup Snapshot and FCM Readiness Design

**Date:** 2026-09-16

## Goal

Make the daily reading ready without repeating its expensive cold-start lookup, while proving whether server FCM fallback is configured to send.

## Evidence

- First frame already renders without awaiting Firebase, notifications, or network.
- `PremiumBrowseScreen` still resolves the day, loads reading sets, hydrates every reading text, and parses calendar assets on each process start.
- The client and Laravel sender use the same schema-3 feast payload and `feast-reminders-v6` generation. Android sends high-priority data-only FCM; iOS sends an alert with mutable content.
- Laravel defaults `FEAST_NOTIFICATION_SERVER_PRIMARY_ENABLED` to `false` and `FEAST_NOTIFICATION_INTERNAL_ONLY` to `true`. Production environment values and FCM credentials are not present in either repository, so they cannot be verified from source alone.

## Selected Design

### Versioned daily snapshot

`DailyReadingSnapshotStore` persists a compact, atomic JSON snapshot for the visible date and a seven-day warm window. Every entry contains the fully hydrated reading model required by the daily view, including read texts, previews, titles, psalm source metadata, liturgical title, reading-set selection, and saint display data.

The key contains:

- local calendar date;
- liturgical region;
- Bible edition/database identity;
- notification/calendar generation; and
- snapshot schema version.

The app reads the one matching entry after the first frame and applies it immediately. It simultaneously performs the authoritative normal resolver path. A successful fresh result atomically replaces the snapshot and prewarms the remaining seven days. Any malformed, expired, mismatched, or incomplete entry is ignored and removed; it can never replace fresh data.

### One bootstrap preference read

`StartupPresentationPreferences` obtains `SharedPreferences` once and exposes theme, onboarding, and resume state. `CatholicDailyApp` and `HomeScreen` receive this result rather than opening separate platform preference requests. Writes remain owned by the existing services.

### FCM readiness boundary

The Flutter client must continue treating local scheduled alarms as the primary delivery path. The server fallback is only considered ready after a deployment-level preflight confirms:

1. `FCM_PROJECT_ID` and service-account project match `elbiblio-fae32`.
2. `FEAST_NOTIFICATION_SERVER_PRIMARY_ENABLED=true`.
3. Internal-only rollout is either explicitly enabled with a registered test installation or intentionally disabled for general delivery.
4. Laravel scheduler/queue execution and notification tables are healthy.
5. A process-terminated Android test installation receives exactly one data-only FCM fallback after its local coverage is invalidated.

This is an operational gate, not a value that an app update can safely force. The app can record its registration and fallback receipt, but it cannot enable production server secrets or scheduler workers.

## Error Handling

- Snapshot reads are bounded to local storage and cannot delay the first frame.
- A snapshot failure falls back to the existing live resolver with no user-visible error.
- Snapshot writes occur only after a complete authoritative hydrate; failed writes do not affect displayed data.
- FCM server configuration remains disabled until the deployment preflight succeeds; local reminders retain independent delivery.

## Verification

- Unit tests cover cache-key invalidation, malformed snapshot rejection, atomic replacement, and warm-window limits.
- Widget tests prove a matching snapshot is shown before an intentionally delayed live hydrate, then fresh data replaces it.
- Existing daily-reading, notification-contract, background, and messaging tests remain green.
- Server readiness requires Laravel tests plus a real Android, process-terminated end-to-end FCM test. Source review alone is insufficient.
