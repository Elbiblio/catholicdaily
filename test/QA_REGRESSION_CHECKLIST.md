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
