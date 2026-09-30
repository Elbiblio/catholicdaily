# Reading Text Size Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provide one clear, persisted reading-text size setting across daily readings and Order of Mass.

**Architecture:** Add a focused `ChangeNotifier` preference backed by `SharedPreferences`, and a reusable modal control that observes it. Reading surfaces subscribe to the same preference and apply its scale only to long-form reading content, leaving navigation and labels governed by platform accessibility scaling.

**Tech Stack:** Flutter, Dart, Material 3, SharedPreferences, flutter_test

---

### Task 1: Persisted preference

**Files:**
- Create: `lib/data/services/reading_text_size_preference.dart`
- Create: `test/data/services/reading_text_size_preference_test.dart`

- [ ] Write tests proving Standard is the default, each choice persists, listeners are notified, and an unsupported stored value recovers to Standard.
- [ ] Run `flutter test test/data/services/reading_text_size_preference_test.dart` and verify the missing implementation fails.
- [ ] Implement `ReadingTextSize`, its labels/scales, and `ReadingTextSizePreference` with `getInstance`, `resetForTest`, and `setSize`.
- [ ] Run the preference test and verify it passes.

### Task 2: Reusable accessible selector

**Files:**
- Create: `lib/ui/widgets/reading_text_size_sheet.dart`
- Create: `test/ui/widgets/reading_text_size_sheet_test.dart`

- [ ] Write a widget test for the preview, five radio choices, immediate selection, and conditional reset action.
- [ ] Run the widget test and verify it fails before implementation.
- [ ] Build a modal sheet with wrapping content, native radio semantics, and 48 dp rows; bind it directly to the preference notifier.
- [ ] Run the widget test and verify it passes.

### Task 3: Settings and daily reading integration

**Files:**
- Modify: `lib/ui/screens/settings_screen.dart`
- Modify: `lib/ui/screens/reading_screen.dart`
- Modify: `lib/ui/widgets/psalm_response_widget.dart`
- Modify: `lib/ui/widgets/gospel_acclamation_widget.dart`
- Create: `test/ui/screens/reading_text_size_integration_test.dart`

- [ ] Write widget tests proving the Settings row is enabled, shows the saved choice, and the reading menu opens the selector and immediately changes scripture body size.
- [ ] Run the integration test and verify it fails against the disabled row and fixed 1.0 scale.
- [ ] Subscribe Settings and ReadingScreen to `ReadingTextSizePreference`, open the shared selector, and pass the selected scale to the psalm and acclamation content widgets.
- [ ] Run the integration and existing reading/settings tests and verify they pass.

### Task 4: Order of Mass integration

**Files:**
- Modify: `lib/ui/screens/mass_flow_screen.dart`
- Modify: `test/ui/screens/mass_flow_narration_test.dart`

- [ ] Add a failing widget test proving expanded Mass reading text uses a supplied 150% scale.
- [ ] Pass the shared reading scale through the Mass reading section and standalone cards and apply it to expanded reading/incipit text.
- [ ] Run Mass flow tests and verify they pass.

### Task 5: Release verification

**Files:**
- Modify: `pubspec.yaml`

- [ ] Format changed Dart files and run `flutter analyze`.
- [ ] Run all Flutter tests and confirm zero failures.
- [ ] Build the Android release artifact and confirm exit code 0.
- [ ] Install the debug build on the connected physical device and smoke-test Settings, daily reading, and Order of Mass at Standard and Extra large.
- [ ] Bump the patch/build version, commit the focused change, fast-forward `main`, tag the release, and push for CI deployment.
