# Saint of the Day Notifications and Deep Links Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a separate opt-in Saint of the Day reminder that schedules reliable offline content, coexists with feast reminders, and opens the correct dated profile from every app lifecycle state.

**Architecture:** Move plugin ownership behind one local-notification gateway and one schedule coordinator. Feast and saint planners produce typed candidates; a pure policy applies category budgets, overlap rules, stable IDs, and truthful horizons before the gateway schedules them. A versioned payload router retains tap intent until onboarding/root navigation is ready and opens a stable profile/date route or a dated-saints fallback.

**Tech Stack:** Flutter/Dart, `flutter_local_notifications` 18, `timezone` 0.9, `shared_preferences`, Material settings UI, existing offline calendar/profile services, Flutter unit/widget tests, Android emulator.

---

**Dependencies:** Complete the foundation plan. Start notification execution after the representative pilot is published; enable the user-facing toggle only when the content gate required in Task 8 is met.

## File responsibility map

- `lib/data/models/planned_local_notification.dart`: plugin-neutral scheduled-notification candidate and category.
- `lib/data/services/local_notification_gateway.dart`: initialization, permission, pending-list, category cancellation, one-off/repeating schedule adapter.
- `lib/data/services/notification_schedule_policy.dart`: pure ID ranges, slot budget, overlap/coalescing, and horizon result.
- `lib/data/services/notification_schedule_coordinator.dart`: build both plans, apply policy, cancel owned IDs only, schedule, and persist truthful results.
- `lib/data/services/feast_reminder_service.dart`: feast candidate planner; no global cancellation or independent plugin instance.
- `lib/data/services/feast_reminder_preferences.dart`: existing feast preference plus coordinator-owned schedule metadata compatibility.
- `lib/data/services/saint_reminder_preferences.dart`: explicit opt-in, local time, schedule version/horizon, and fallback state.
- `lib/data/services/saint_of_day_selector.dart`: choose primary and secondary published profiles using date/region/calendar order.
- `lib/data/services/saint_reminder_service.dart`: build personalized rolling-window candidates and generic continuity candidate.
- `lib/data/models/notification_deep_link.dart`: strict payload parsing and serialization.
- `lib/data/services/notification_tap_router.dart`: retain/consume cold, warm, foreground, and initialization-delayed tap intent.
- `lib/ui/screens/saints_for_date_screen.dart`: safe dated fallback when a target becomes stale or ambiguous.
- `lib/ui/screens/saint_detail_screen.dart`: stable profile-ID/date constructor in addition to celebration constructor.
- `lib/ui/screens/saint_reminder_settings_sheet.dart`: opt-in, time selection, permission result, and scheduling status.
- `lib/ui/screens/settings_screen.dart`: separate Saint of the Day settings row.
- `lib/main.dart`: initialize one notification stack, capture launch payload, attach root navigator, and drain retained intent after onboarding.
- `test/data/services/notification_schedule_policy_test.dart`: category budget, overlap, ID, and horizon tests.
- `test/data/services/saint_of_day_selector_test.dart`: precedence, publication, multiple-celebration, and no-profile tests.
- `test/data/services/saint_reminder_service_test.dart`: rolling window, generic fallback, timezone, and partial coverage tests.
- `test/data/models/notification_deep_link_test.dart`: strict and backward-compatible payload tests.
- `test/data/services/notification_tap_router_test.dart`: lifecycle retention and single-consumption tests.
- `test/ui/screens/saint_reminder_settings_sheet_test.dart`: opt-in/permission/schedule UX.
- `test/ui/screens/saint_notification_navigation_test.dart`: root-level cold/warm/fallback navigation.

### Task 1: Introduce a plugin-neutral notification gateway

**Files:**
- Create: `lib/data/models/planned_local_notification.dart`
- Create: `lib/data/services/local_notification_gateway.dart`
- Test: `test/data/services/local_notification_gateway_test.dart`

- [ ] **Step 1: Write the failing category-cancellation test**

```dart
test('cancelCategory cancels only pending requests owned by that payload', () async {
  final plugin = FakeNotificationPlugin(pending: const [
    PendingLocalNotification(id: 1001, payload: 'feast:v1:2026-08-15:day'),
    PendingLocalNotification(id: 3001, payload: 'saint:v1:2026-08-15:mary'),
    PendingLocalNotification(id: 77, payload: null),
  ]);
  final gateway = LocalNotificationGateway(plugin: plugin);

  await gateway.cancelCategory(NotificationCategory.saint);

  expect(plugin.cancelledIds, [3001]);
});
```

- [ ] **Step 2: Run the test to verify failure**

Run: `flutter test test/data/services/local_notification_gateway_test.dart`

Expected: FAIL because the gateway and typed models do not exist.

- [ ] **Step 3: Implement the planned notification model**

```dart
enum NotificationCategory { feast, saint }

class PlannedLocalNotification {
  const PlannedLocalNotification({
    required this.category,
    required this.semanticKey,
    required this.title,
    required this.body,
    required this.scheduledAt,
    required this.payload,
    required this.isRepeatingDaily,
    this.celebrationId,
    this.overlapKey,
    this.celebrationDate,
    this.isEve = false,
  });

  final NotificationCategory category;
  final String semanticKey;
  final String title;
  final String body;
  final DateTime scheduledAt;
  final String payload;
  final bool isRepeatingDaily;
  final String? celebrationId;
  final String? overlapKey;
  final DateTime? celebrationDate;
  final bool isEve;
}
```

- [ ] **Step 4: Implement the gateway and adapter seam**

Expose a small `NotificationPluginAdapter` interface with `initialize`, `requestPermission`, `canScheduleExact`, `pending`, `cancel`, `scheduleOneOff`, and `scheduleDailyFrom`. Implement the production adapter with the existing plugin. Use Android channel `feast_reminders` for feast candidates and a new `saint_of_the_day` channel for saint candidates; use matching separate iOS thread/category identifiers. In the test file, define `FakeNotificationPlugin implements NotificationPluginAdapter` with an in-memory pending list, a `cancelledIds` list, captured schedule calls, configurable permission/exact results, and methods that synchronously record each invocation. `LocalNotificationGateway.initialize` accepts `ValueChanged<String?> onTap`, passes it to `onDidReceiveNotificationResponse`, and returns the launch payload from `getNotificationAppLaunchDetails`. `cancelCategory` loads pending requests and cancels only payloads beginning with `feast:` or `saint:`. No production method may call `cancelAll()`.

- [ ] **Step 5: Add gateway tests for null/malformed payloads and tap forwarding**

Assert that category cancellation ignores null, foreign, and malformed payloads, scheduling forwards exact/inexact mode correctly, and initialization forwards both runtime and launch payloads once.

- [ ] **Step 6: Format, test, and commit**

Run: `dart format lib/data/models/planned_local_notification.dart lib/data/services/local_notification_gateway.dart test/data/services/local_notification_gateway_test.dart && flutter test test/data/services/local_notification_gateway_test.dart`

Expected: PASS.

```powershell
git add lib/data/models/planned_local_notification.dart lib/data/services/local_notification_gateway.dart test/data/services/local_notification_gateway_test.dart
git commit -m "feat: centralize local notification access"
```

### Task 2: Define shared IDs, budgets, overlap, and horizon policy

**Files:**
- Create: `lib/data/services/notification_schedule_policy.dart`
- Create: `test/data/services/notification_schedule_policy_test.dart`

- [ ] **Step 1: Write failing policy tests**

```dart
test('both categories stay under sixty pending slots', () {
  final candidates = [
    ...List.generate(40, saintCandidate),
    ...List.generate(40, feastCandidate),
    saintFallbackCandidate(),
  ];

  final result = const NotificationSchedulePolicy().select(
    candidates,
    saintEnabled: true,
    feastEnabled: true,
  );

  expect(result.selected, hasLength(60));
  expect(result.selected.where((n) => n.category == NotificationCategory.saint), hasLength(29));
  expect(result.selected.where((n) => n.category == NotificationCategory.feast), hasLength(31));
  expect(result.selected.where((n) => n.isRepeatingDaily), hasLength(1));
});

test('same-day feast is coalesced but eve reminder remains', () {
  final result = const NotificationSchedulePolicy().select(
    [
      saintCandidate(0, celebrationId: 'mary', hour: 7),
      feastCandidate(0, celebrationId: 'mary', hour: 9, isEve: false),
      feastCandidate(0, celebrationId: 'mary', hour: 20, isEve: true),
    ],
    saintEnabled: true,
    feastEnabled: true,
  );

  expect(result.selected.where((n) => n.isEve), hasLength(1));
  expect(result.coalescedFeastKeys, hasLength(1));
});
```

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/data/services/notification_schedule_policy_test.dart`

Expected: FAIL because the policy does not exist.

- [ ] **Step 3: Implement deterministic selection**

Use these constants:

```dart
static const maxPending = 60;
static const bothSaintSlots = 29; // 28 personalized + one daily fallback
static const bothFeastSlots = 31;
static const saintIdStart = 3000;
static const feastIdStart = 1000;
static const categoryIdRangeSize = 1000;
static const overlapWindow = Duration(hours: 6);
```

Sort by `scheduledAt`, then `semanticKey`. When both categories are enabled, first reserve up to the fixed allocations, then reassign any unused quota to the other category’s remaining candidates in chronological order; this prevents sparse initial saint coverage from wasting slots needed by feast reminders. When one category is disabled, allocate 59 one-off slots plus at most one repeating fallback to the enabled category. Coalesce only a non-eve feast occurrence whose canonical `overlapKey` and local `celebrationDate` match the saint candidate and whose delivery times are within six hours. Retain the saint title/body and record the removed feast semantic key for truthful result reporting.

Assign stable integer IDs from a 31-bit FNV-1a hash of `category:semanticKey`, mapped into the category range, with deterministic linear probing inside that category’s range on collision. Tests must prove stable IDs across candidate order changes and no cross-category collisions.

- [ ] **Step 4: Implement truthful results**

`NotificationScheduleSelection` exposes selected notifications with IDs, rejected-capacity count, coalesced keys, and per-category latest one-off scheduled time. A category horizon is null when it had eligible candidates but none were selected or when every selected schedule later fails; the coordinator will combine policy selection with gateway results.

- [ ] **Step 5: Run tests and commit**

Run: `dart format lib/data/services/notification_schedule_policy.dart test/data/services/notification_schedule_policy_test.dart && flutter test test/data/services/notification_schedule_policy_test.dart`

Expected: PASS.

```powershell
git add lib/data/services/notification_schedule_policy.dart test/data/services/notification_schedule_policy_test.dart
git commit -m "feat: coordinate notification capacity and overlap"
```

### Task 3: Refactor feast reminders into a category-safe planner

**Files:**
- Modify: `lib/data/services/feast_reminder_service.dart`
- Modify: `lib/data/services/feast_reminder_schedule_policy.dart`
- Modify: `test/data/services/feast_reminder_schedule_policy_test.dart`
- Create: `test/data/services/feast_reminder_planner_test.dart`

- [ ] **Step 1: Write the failing planner test**

Call a new `buildPlan` method for a fixed `now`, region, preferences, and horizon. Assert that every result has category `feast`, a `feast:v1:` payload, celebration date/ID, correct eve flag, and no plugin side effect. Add a source scan test that reads `feast_reminder_service.dart` and rejects `.cancelAll()`.

- [ ] **Step 2: Run feast tests to verify failure**

Run: `flutter test test/data/services/feast_reminder_schedule_policy_test.dart test/data/services/feast_reminder_planner_test.dart`

Expected: FAIL because `buildPlan` does not exist and global cancellation is still present.

- [ ] **Step 3: Extract planning from scheduling**

Convert `_ReminderOccurrence` into `PlannedLocalNotification` values without changing date/rank/secondary-reminder rules. The payload format becomes:

```text
feast:v1:<yyyy-mm-dd>:<celebration-id>:eve
feast:v1:<yyyy-mm-dd>:<celebration-id>:day
```

Resolve the offline ordo title/date through `SaintProfileService.findCuratedForCelebration` when possible and use the matched profile ID as `overlapKey`; otherwise use `SaintProfileService.normalizeTitle(title)`. Keep the source celebration ID for navigation/diagnostics, deriving it with `SaintProfileService.idFromTitle` only when the offline ordo record has no stable ID. This ensures a title-derived feast such as an Assumption or Marian celebration can coalesce with the canonical researched profile. Keep existing preview methods by mapping the new candidate list.

- [ ] **Step 4: Remove plugin ownership and global cancellation**

Replace the private plugin with an injected `LocalNotificationGateway`. Until the coordinator is created in Task 6, keep public scheduling entry points operational through the gateway and replace every global cancellation with `cancelCategory(NotificationCategory.feast)`. This preserves a compiling, working commit boundary. Task 6 moves all final permission/scheduling ownership to the coordinator and removes these compatibility entry points after all callers switch.

- [ ] **Step 5: Run all feast tests**

Run: `dart format lib/data/services/feast_reminder_service.dart test/data/services/feast_reminder_planner_test.dart && flutter test test/data/services/feast_reminder_schedule_policy_test.dart test/data/services/feast_reminder_planner_test.dart`

Expected: PASS; source scan confirms no `cancelAll()`.

- [ ] **Step 6: Commit the feast planner**

```powershell
git add lib/data/services/feast_reminder_service.dart lib/data/services/feast_reminder_schedule_policy.dart test/data/services/feast_reminder_schedule_policy_test.dart test/data/services/feast_reminder_planner_test.dart
git commit -m "refactor: make feast reminders category safe"
```

### Task 4: Add Saint preferences and primary-profile selection

**Files:**
- Create: `lib/data/services/saint_reminder_preferences.dart`
- Create: `lib/data/services/saint_of_day_selector.dart`
- Create: `test/data/services/saint_reminder_preferences_test.dart`
- Create: `test/data/services/saint_of_day_selector_test.dart`

- [ ] **Step 1: Write preference tests**

Use `SharedPreferences.setMockInitialValues`. Assert default disabled, default time 07:00, independent keys from feast reminders, setters, time label, schedule invalidation, schema version, personalized horizon, fallback start, and that disabling clears saint schedule metadata without changing feast keys.

- [ ] **Step 2: Write selector tests**

Inject calendar and profile lookup functions. Assert this order:

1. published solemnity;
2. published feast;
3. published obligatory memorial;
4. published optional memorial;
5. original calendar order as tie-breaker.

Draft/invalid profiles are excluded. The result exposes one primary selection plus published secondary selections. When a calendar celebration has no published profile, it is omitted; no next-date saint is substituted.

- [ ] **Step 3: Run tests to verify failure**

Run: `flutter test test/data/services/saint_reminder_preferences_test.dart test/data/services/saint_of_day_selector_test.dart`

Expected: FAIL because the types do not exist.

- [ ] **Step 4: Implement preferences**

Use keys prefixed `saint_reminder_`, an injected `SharedPreferences` test constructor, and these getters:

```dart
bool get isEnabled;
int get hour;
int get minute;
int get scheduleSchemaVersion;
DateTime? get scheduledThrough;
DateTime? get fallbackStartsAt;
String get timeLabel;
```

All mutating preference changes invalidate only the saint schedule.

- [ ] **Step 5: Implement selector**

`SaintOfDaySelector.select(DateTime date)` calls `SaintCalendarService.getSaintCelebrationsForDate`, looks up curated profiles by celebration, filters `isPublished && hasFullGuide`, sorts by explicit rank weight while preserving source order, and returns `SaintOfDaySelection?` with date, primary celebration/profile, and secondary celebration/profile pairs.

- [ ] **Step 6: Run tests and commit**

Run: `dart format lib/data/services/saint_reminder_preferences.dart lib/data/services/saint_of_day_selector.dart test/data/services/saint_reminder_preferences_test.dart test/data/services/saint_of_day_selector_test.dart && flutter test test/data/services/saint_reminder_preferences_test.dart test/data/services/saint_of_day_selector_test.dart`

Expected: PASS.

```powershell
git add lib/data/services/saint_reminder_preferences.dart lib/data/services/saint_of_day_selector.dart test/data/services/saint_reminder_preferences_test.dart test/data/services/saint_of_day_selector_test.dart
git commit -m "feat: select published saint of the day"
```

### Task 5: Build personalized and continuity saint plans

**Files:**
- Create: `lib/data/services/saint_reminder_service.dart`
- Create: `test/data/services/saint_reminder_service_test.dart`

- [ ] **Step 1: Write failing plan tests**

Assert that `buildPlan(now, days: 28, preferences)`:

- skips past delivery times and dates without published profiles;
- emits at most one personalized saint notification per local date;
- uses the primary profile ID/date in `saint:v1:<date>:<id>`;
- derives title `Today: <profile.name>` and body from `whyItMatters`, trimmed to a tested platform-safe length without splitting a Unicode scalar;
- appends one repeating fallback beginning at the chosen local time on day 29 with payload `saint:v1:today` only when an injected coverage check confirms that every local date in the supported continuity window has a published profile;
- emits no generic fallback for the initial sparse 158-date coverage, preventing a notification from promising content on an uncovered date;
- emits no plan when disabled; and
- remains deterministic across repeated calls.

- [ ] **Step 2: Run the test to verify failure**

Run: `flutter test test/data/services/saint_reminder_service_test.dart`

Expected: FAIL because the planner does not exist.

- [ ] **Step 3: Implement the saint planner**

Inject `SaintOfDaySelector`, `Future<bool> Function(DateTime start) hasContinuousCoverage`, and `DateTime Function()` for tests. Iterate local calendar dates from today through day 28, resolve each selection, create one-off candidates at the selected hour/minute, and add the fallback starting on day 29 only when `hasContinuousCoverage` succeeds. The production coverage check scans the next 366 local dates and returns true only when each resolves a published profile; this remains false for the initial 158-profile corpus and becomes eligible during year-round expansion. Use semantic keys `saint:<date>:<profileId>` and `saint:fallback:<hour>:<minute>`. The fallback copy is exact and does not name a profile:

```text
Title: Meet today’s saint
Body: Discover a witness of faith and one practical step for today.
```

- [ ] **Step 4: Add time-zone and partial-coverage tests**

Set representative local dates around midnight and DST-capable timezone fixtures. Assert calendar date—not UTC date—drives selection. Assert sparse coverage schedules only available published dates and no generic fallback; assert a complete 366-day fixture positions the generic fallback after the full 28-day personalized window.

- [ ] **Step 5: Run tests and commit**

Run: `dart format lib/data/services/saint_reminder_service.dart test/data/services/saint_reminder_service_test.dart && flutter test test/data/services/saint_reminder_service_test.dart`

Expected: PASS.

```powershell
git add lib/data/services/saint_reminder_service.dart test/data/services/saint_reminder_service_test.dart
git commit -m "feat: plan daily saint reminders"
```

### Task 6: Coordinate scheduling and persist truthful horizons

**Files:**
- Create: `lib/data/services/notification_schedule_coordinator.dart`
- Modify: `lib/data/services/feast_reminder_preferences.dart`
- Test: `test/data/services/notification_schedule_coordinator_test.dart`

- [ ] **Step 1: Write coordinator failure tests**

With fake planners/gateway, cover:

- saint reschedule leaves foreign and feast pending notifications untouched until the combined replacement is ready;
- feast reschedule leaves saint notifications intact;
- combined scheduling cancels only owned category IDs;
- partial gateway failure persists each category’s latest successful one-off time;
- total failure leaves the category horizon null and cancels any newly scheduled partial set only when consistency cannot be guaranteed;
- exact-alarm denial uses inexact scheduling without disabling preferences; and
- overlap result counts coalesced same-day feasts while retaining eve reminders.

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/data/services/notification_schedule_coordinator_test.dart`

Expected: FAIL because the coordinator does not exist.

- [ ] **Step 3: Implement atomic category replacement**

Build both enabled plans first and validate them. Ask the policy for selected candidates and IDs. Schedule candidates under a new schedule generation before cancelling obsolete owned requests; if an ID already exists with the same payload/time, keep it. After successful scheduling, cancel old owned IDs not in the selected set. This minimizes reminder gaps and never touches foreign notifications.

Persist per-category result only from successful gateway calls. Add a schema version covering payload, ID, budget, and overlap rules. `rescheduleIfNeeded` checks schema plus a seven-day replenishment lead time for the 28-day saint horizon and the existing lead policy for feast candidates.

- [ ] **Step 4: Route all feast scheduling callers through the coordinator**

Keep behavior of onboarding, settings, region change, and startup, but replace direct `FeastReminderService.scheduleAheadMonths` calls with `NotificationScheduleCoordinator.rescheduleAll`. Remove compatibility scheduling methods after `rg` proves no caller remains.

- [ ] **Step 5: Run coordinator, feast, and saint tests**

Run: `dart format lib/data/services/notification_schedule_coordinator.dart lib/data/services/feast_reminder_preferences.dart && flutter test test/data/services/notification_schedule_coordinator_test.dart test/data/services/feast_reminder_schedule_policy_test.dart test/data/services/feast_reminder_planner_test.dart test/data/services/saint_reminder_service_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit coordinated scheduling**

```powershell
git add lib/data/services/notification_schedule_coordinator.dart lib/data/services/feast_reminder_preferences.dart lib/data/services/feast_reminder_service.dart lib/main.dart lib/ui/screens/settings_screen.dart lib/ui/screens/onboarding_screen.dart test/data/services/notification_schedule_coordinator_test.dart
git commit -m "feat: coordinate feast and saint reminders"
```

### Task 7: Parse and retain notification deep links

**Files:**
- Create: `lib/data/models/notification_deep_link.dart`
- Create: `lib/data/services/notification_tap_router.dart`
- Create: `test/data/models/notification_deep_link_test.dart`
- Create: `test/data/services/notification_tap_router_test.dart`

- [ ] **Step 1: Write strict parser tests**

```dart
test('parses versioned personalized saint payload', () {
  final link = NotificationDeepLink.tryParse(
    'saint:v1:2026-08-10:lawrence_of_rome_deacon',
  );

  expect(link, isA<SaintProfileDeepLink>());
  expect((link! as SaintProfileDeepLink).date, DateTime(2026, 8, 10));
  expect(link.profileId, 'lawrence_of_rome_deacon');
});

test('rejects traversal, invalid dates, versions, and extra fields', () {
  expect(NotificationDeepLink.tryParse('saint:v1:2026-02-30:x'), isNull);
  expect(NotificationDeepLink.tryParse('saint:v2:today'), isNull);
  expect(NotificationDeepLink.tryParse('saint:v1:2026-08-10:../x'), isNull);
  expect(NotificationDeepLink.tryParse('saint:v1:today:extra'), isNull);
});
```

Also parse `saint:v1:today` and current/legacy feast payloads into dated fallback links without crashing.

- [ ] **Step 2: Write tap-router lifecycle tests**

Assert that a link received before navigation readiness is retained, survives onboarding readiness changes, is consumed exactly once after a listener attaches, a newer explicit tap supersedes an unconsumed older tap, and malformed payloads produce no navigation event.

- [ ] **Step 3: Run tests to verify failure**

Run: `flutter test test/data/models/notification_deep_link_test.dart test/data/services/notification_tap_router_test.dart`

Expected: FAIL because the parser/router do not exist.

- [ ] **Step 4: Implement strict types and router**

Use sealed types `SaintProfileDeepLink`, `TodaySaintDeepLink`, and `FeastDateDeepLink`. Validate profile IDs with `RegExp(r'^[a-z0-9_]+$')` and confirm parsed dates round-trip year/month/day. `NotificationTapRouter` is a `ChangeNotifier` with `acceptPayload`, `setNavigationReady`, and `takePending`; it never persists payloads to disk and clears on successful consumption.

- [ ] **Step 5: Run tests and commit**

Run: `dart format lib/data/models/notification_deep_link.dart lib/data/services/notification_tap_router.dart test/data/models/notification_deep_link_test.dart test/data/services/notification_tap_router_test.dart && flutter test test/data/models/notification_deep_link_test.dart test/data/services/notification_tap_router_test.dart`

Expected: PASS.

```powershell
git add lib/data/models/notification_deep_link.dart lib/data/services/notification_tap_router.dart test/data/models/notification_deep_link_test.dart test/data/services/notification_tap_router_test.dart
git commit -m "feat: retain notification deep links"
```

### Task 8: Add root navigation and dated fallback screens

**Files:**
- Create: `lib/ui/screens/saints_for_date_screen.dart`
- Modify: `lib/ui/screens/saint_detail_screen.dart`
- Modify: `lib/main.dart`
- Create: `test/ui/screens/saint_notification_navigation_test.dart`

- [ ] **Step 1: Write root navigation tests**

Pump `CatholicDailyApp` with injected tap router, profile service, and onboarding-complete state. Cover:

- cold-start personalized payload waits for app initialization, then opens the matching profile/date;
- warm and foreground payloads open once;
- payload received during onboarding opens only after completion;
- `saint:v1:today` resolves the actual open date;
- missing/unpublished/mismatched profile falls back to `SaintsForDateScreen`; and
- a dated fallback with no published profiles shows a safe “No researched saint profile is available for this date” message.

- [ ] **Step 2: Run the test to verify failure**

Run: `flutter test test/ui/screens/saint_notification_navigation_test.dart`

Expected: FAIL because root navigation and fallback route do not exist.

- [ ] **Step 3: Add a stable-ID/date detail constructor**

Add `SaintDetailScreen.forProfile({required String profileId, required DateTime date})`. It loads by stable ID, asks `SaintCalendarService` for that date, matches the profile’s celebration IDs, and builds the header from the matched celebration. If no matching dated celebration exists, return a typed stale-target result for the root router instead of fabricating a rank/date.

- [ ] **Step 4: Implement `SaintsForDateScreen`**

Load published selections for the supplied local date, render the date plus primary/secondary cards, and navigate by stable ID/date. This is the only fallback for stale saint/feast notification payloads; it never substitutes another date.

- [ ] **Step 5: Wire the root navigator**

Give `MaterialApp` a `GlobalKey<NavigatorState>`. Initialize the gateway before `runApp`, feed launch/runtime payloads to a single router, attach a router listener in `CatholicDailyApp`, and mark navigation ready only after onboarding and root initialization complete. Consume links with `navigatorKey.currentState!.push(...)`; after returning from onboarding, drain the retained link before resume-to-last-Bible navigation can supersede it.

- [ ] **Step 6: Run navigation tests and commit**

Run: `dart format lib/ui/screens/saints_for_date_screen.dart lib/ui/screens/saint_detail_screen.dart lib/main.dart test/ui/screens/saint_notification_navigation_test.dart && flutter test test/ui/screens/saint_notification_navigation_test.dart test/ui/screens/saint_detail_screen_test.dart`

Expected: PASS.

```powershell
git add lib/ui/screens/saints_for_date_screen.dart lib/ui/screens/saint_detail_screen.dart lib/main.dart test/ui/screens/saint_notification_navigation_test.dart
git commit -m "feat: open saints from notification taps"
```

### Task 9: Add separate Saint reminder settings

**Files:**
- Create: `lib/ui/screens/saint_reminder_settings_sheet.dart`
- Modify: `lib/ui/screens/settings_screen.dart`
- Create: `test/ui/screens/saint_reminder_settings_sheet_test.dart`

- [ ] **Step 1: Write settings tests**

Assert separate `Saint of the Day` and `Feast Day Reminders` rows. In the saint sheet, assert default off, 07:00 default, time picker result, permission denial message with OS-settings guidance, enable success only after at least one personalized or continuity notification schedules, disable cancels only saint-category requests, and schedule failure leaves the toggle off with an actionable error.

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/ui/screens/saint_reminder_settings_sheet_test.dart`

Expected: FAIL because the sheet/row do not exist.

- [ ] **Step 3: Implement the settings sheet**

Inject preferences, gateway permission request, and coordinator reschedule callback. On enable: request permission, persist enabled only after permission succeeds, call coordinator, and roll back enabled state if no saint notification is scheduled. On disable: persist false, invalidate saint horizon, and invoke combined reschedule so feast notifications remain. Display personalized coverage through date plus the generic continuity status.

- [ ] **Step 4: Add the Settings row**

Under `Reminders`, use a two-row card separated by a divider. Saint subtitle is `Off`, `<time> · personalized through <date>`, or `<time> · daily continuity active`. Reload both preference objects after either sheet closes and after region change.

- [ ] **Step 5: Run settings and existing settings tests**

Run: `dart format lib/ui/screens/saint_reminder_settings_sheet.dart lib/ui/screens/settings_screen.dart test/ui/screens/saint_reminder_settings_sheet_test.dart && flutter test test/ui/screens/saint_reminder_settings_sheet_test.dart test/ui/screens/settings_bible_preference_test.dart test/ui/screens/settings_download_error_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit settings**

```powershell
git add lib/ui/screens/saint_reminder_settings_sheet.dart lib/ui/screens/settings_screen.dart test/ui/screens/saint_reminder_settings_sheet_test.dart
git commit -m "feat: add saint reminder settings"
```

### Task 10: Complete startup, region, and emulator verification

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/ui/screens/onboarding_screen.dart` only if needed to preserve feast choice while initializing the shared coordinator; do not opt users into Saint reminders during onboarding.
- Modify: `lib/ui/screens/settings_screen.dart`
- Modify only tests corresponding to defects found.

- [ ] **Step 1: Add startup and region regression tests**

Assert startup initializes the gateway once, reschedules both enabled categories only when their horizon/schema requires it, and never blocks app launch on notification failure. Assert changing liturgical region invalidates and rebuilds both plans, while changing Bible/theme settings does not.

- [ ] **Step 2: Run the complete notification-focused suite**

Run:

```powershell
flutter test test/data/services/local_notification_gateway_test.dart test/data/services/notification_schedule_policy_test.dart test/data/services/notification_schedule_coordinator_test.dart test/data/services/feast_reminder_schedule_policy_test.dart test/data/services/feast_reminder_planner_test.dart test/data/services/saint_reminder_preferences_test.dart test/data/services/saint_of_day_selector_test.dart test/data/services/saint_reminder_service_test.dart test/data/models/notification_deep_link_test.dart test/data/services/notification_tap_router_test.dart test/ui/screens/saint_reminder_settings_sheet_test.dart test/ui/screens/saint_notification_navigation_test.dart
```

Expected: PASS.

- [ ] **Step 3: Run static and complete verification**

Run:

```powershell
flutter analyze
flutter test
dart run tool/validate_saint_profiles.dart --published-only
flutter build apk --debug
```

Expected: every command exits 0.

- [ ] **Step 4: Verify on an Android emulator**

Use a debug build and perform this exact matrix:

1. Enable Feast reminders and Saint of the Day at different times; confirm both categories appear in pending requests.
2. Change Saint time; confirm feast pending requests remain.
3. Change feast rank/time; confirm saint pending requests remain.
4. Choose a date/profile with same-day overlap; confirm one saint notification plus the eve feast notification, not two morning notifications.
5. Tap a personalized saint notification while app is killed, backgrounded, and foregrounded; confirm the same profile/date each time.
6. With the complete-coverage integration fixture enabled, tap a generic continuity notification after changing device date; confirm the actual open date resolves. In the production 158-profile corpus, confirm no generic fallback is scheduled.
7. Tap during onboarding on a clean install; confirm navigation waits and opens once after onboarding.
8. Deny permission, deny exact-alarm permission, change timezone, reboot emulator, and relaunch; confirm honest settings status and safe rescheduling.
9. Turn Saint reminders off; confirm feast reminders remain pending.
10. Turn Feast reminders off; confirm saint reminders remain pending.

Capture screenshots and `adb shell dumpsys notification`/pending-request evidence under `verification/saint-notifications/` without committing device artifacts unless the repository’s verification policy explicitly tracks them.

- [ ] **Step 5: Commit verified integration corrections**

If emulator or full-suite verification required corrections, rerun the failed case and complete focused suite before committing:

```powershell
git add lib test
git commit -m "fix: harden saint notification lifecycle"
```

If no correction was required, do not create an empty commit.
