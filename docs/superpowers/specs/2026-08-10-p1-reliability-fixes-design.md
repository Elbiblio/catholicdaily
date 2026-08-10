# P1 Reliability Fixes Design

## Objective

Fix the five highest-priority reliability defects identified in the August 10 audit without broad unrelated refactoring:

1. feast reminders silently failing or aging out;
2. stale and mixed-date reading loads;
3. reading navigation growing a stale route stack and losing liturgical context;
4. downloaded Bible translations being unusable;
5. partial Bible downloads being treated as installed.

## Product decisions

The app serves Catholic users who expect daily readings and reminders to be dependable and understandable rather than technically exact at the cost of delivery.

- Android reminders use exact delivery when exact-alarm access is available. If it is unavailable, reminders fall back to inexact delivery instead of disappearing.
- Notification settings report successful scheduling only when at least one notification was actually scheduled. A total scheduling failure leaves the schedule stale so the next launch retries.
- Reminder replenishment is based on an explicit scheduled-through timestamp, not a comparison between unlike calendar years.
- The platform notification cap is treated as a rolling horizon. The app replenishes when the scheduled-through date is near or behind the current date.
- Rapid date changes are latest-request-wins. A completed request may commit state only if it still represents the newest requested date.
- Next/previous reading actions replace the current reading route. The selected liturgical day travels with the entire reading session.
- The download catalog exposes only translations the renderer can actually open. For the current Catholic product scope, the supported downloadable source is the Douay-Rheims database (`engdra.db`). Non-Catholic remote entries are not offered by this screen.
- Bible downloads are written to a temporary file, validated as a readable SQLite Bible database, and atomically renamed. Failed or interrupted downloads leave no installed marker.

## Architecture

### Reminder scheduling

`FeastReminderService` will return a schedule result containing the number scheduled, the last scheduled occurrence, whether exact delivery was used, and any failure count. Android capability detection will use `canScheduleExactNotifications()`. Enabling reminders may request exact-alarm access, but denial is not fatal; scheduling selects `exactAllowWhileIdle` or `inexactAllowWhileIdle` accordingly.

`FeastReminderPreferences` will persist a scheduled-through timestamp. `rescheduleIfNeeded` will replenish when the schema changes, no valid horizon exists, or the horizon is within a safety window. Successful metadata is persisted only after at least one notification is scheduled (or there are genuinely no eligible occurrences in the requested range).

Pure schedule-decision and horizon functions will be directly unit tested. Plugin calls remain behind small injectable/callable boundaries so tests do not assert method-channel implementation details.

### Date loading

`PremiumBrowseScreen` and `MassFlowScreen` will increment a request generation for each load. Each load captures an immutable normalized date and uses it for every resolver/backend/hydration call. Before committing success, error, loading, or animation state, it verifies both `mounted` and that its generation is current.

The generation rule will live in a small reusable `LatestRequestGuard` utility with deterministic unit tests; widget tests will cover the relevant screen behavior where dependencies permit.

### Reading navigation context

`ReadingSession` will carry the `LiturgicalDay` associated with its readings. Session construction from browse selection stores that value. All subsequent navigation uses the session value instead of `null`.

Next, previous, and variant selection will replace the current reading route rather than pushing another route. Direct opening from Browse or Bible search remains a push. This keeps Back semantics stable and prevents old screens from controlling a newer global session index.

### Downloadable Bible source

The source registry will distinguish bundled and downloaded local databases. It will register Douay-Rheims as a supported user-downloaded Catholic source. The Bible preference remains source-ID based while retaining compatibility helpers for the existing enum call sites.

The settings selector will be built from currently available local sources, so Douay-Rheims appears only after a valid download. The readings backend will open bundled sources through the existing asset-copy path and downloaded sources from the application documents directory.

The remote catalog parser will match supported sources by database filename, ignore unsupported entries, and never trust the server's `preinstalled` flag for local availability.

## Error handling

- Exact-alarm denial falls back to approximate delivery.
- Total reminder scheduling failure is visible to callers and does not advance the persisted horizon.
- Stale date-load completions are discarded silently.
- A failed Bible download removes its temporary file and preserves any previously valid installed database.
- SQLite validation requires the expected `books` and `verses` tables before installation.
- Settings shows a concise failure message when download or validation fails.

## Test strategy

Each production change follows red-green-refactor:

- reminder horizon decision, exact/inexact selection, and failure persistence tests;
- stale request generation tests and screen-level delayed-completion tests where practical;
- reading-session liturgical-context and replacement-navigation widget tests;
- supported catalog filtering, atomic download cleanup, schema validation, and selection tests;
- existing analyzer, full Flutter test suite, web/Android/Windows builds as applicable;
- Android emulator verification for notification permission states, rapid date taps, route-stack behavior, and downloaded-source selection.

## Non-goals

- Adding every translation returned by the remote generic Bible catalog.
- Redesigning Settings or reading screens.
- Replacing the notification plugin.
- Refactoring the large lectionary resolver or changing liturgical data.
