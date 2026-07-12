# CatholicDaily Regression Checklist

## Core Runtime (P0)
- Verify chapter content changes when Bible version is switched between RSVCE and NABRE.
- Verify hymns load and open without crashes.

## State Safety + Data Integrity (P1)
- Open `ReadingScreen`, quickly navigate back/forward, and confirm no setState-after-dispose crashes.
- Toggle bookmarks from `ReadingScreen` and confirm updates are reflected in `BibleScreen` quick access.
- Submit feedback in `SettingsScreen` and confirm failed HTTP responses show a safe failure message.
- Trigger church fetch failures and confirm `ChurchLocatorScreen` shows a safe retryable error.
- Attempt offline Bible download failure and confirm a clear failure is surfaced.

## UX + Accessibility (P2)
- Verify chapter grid in `SearchScreen` adapts on narrow and wide layouts.
- Verify icon-only actions in `ReadingScreen`, `PrayerDetailScreen`, and `BibleScreen` expose tooltips.
- Verify liturgical date in `MassFlowScreen` is formatted with `intl` output.
- Verify dark and light mode contrast remains legible in modified screens.

## Automation Gate
- Run `flutter analyze` and ensure zero issues.
- Run `flutter test test/language_switcher_test.dart test/bible_cache_service_test.dart`.
- Run full test suite and record unrelated pre-existing failures before release decisions.

## Comprehensive Readings Emulator Matrix
- Run on Android emulator `emulator-5554` after comprehensive resolver audit passes.
- For each row: set liturgical region, set Bible version where selectable, navigate to date in Browse/Mass readings, verify celebration title/references/psalm/acclamation/text, capture XML and screenshot to `verification/comprehensive-readings-audit/`.

| Date | Region | Version | Expected focus |
| --- | --- | --- | --- |
| 2026-07-15 | General Roman | RSVCE | Ordinary weekday has first reading, psalm, gospel |
| 2026-08-15 | United States | NABRE | Assumption propers |
| 2026-10-01 | Nigeria | RSVCE | Our Lady, Queen of Nigeria / regional handling |
| 2027-05-13 | United States - Ascension Thursday | NABRE | Ascension on Thursday |
| 2027-05-16 | United States | NABRE | Transferred Ascension profile |
| 2027-05-16 | England & Wales | RSVCE | Region transfer behavior visible |
| 2030-12-25 | England & Wales | RSVCE | Christmas propers beyond 2026 |
