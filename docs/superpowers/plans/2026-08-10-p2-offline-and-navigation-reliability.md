# P2 Offline and Navigation Reliability Implementation Plan

> Execute each task test-first. Keep commits scoped to P2 files and preserve unrelated workspace artifacts.

**Goal:** Make Mass Flow date ownership and offline Bible-source recovery reliable under delayed requests, network failure, and damaged local downloads.

**Architecture:** Add a small Mass Flow request-state model, enhance `OfflineBibleService`'s fallback catalog, and make `ReadingsBackendIo` recover optional local-source failures by persisting and opening RSVCE.

**Tech stack:** Flutter/Dart, `flutter_test`, `sqflite_common_ffi`, `http/testing`, SharedPreferences test mocks.

---

## Task 1: Preserve the newest Mass Flow date request

**Files:**

- Create: `lib/data/models/mass_flow_request_state.dart`
- Create: `test/data/models/mass_flow_request_state_test.dart`
- Modify: `lib/ui/screens/mass_flow_screen.dart`

1. Write a failing unit test proving that requesting date B changes the reload target immediately while date A remains committed.
2. Add a request-state object with `requestedDate`, `committedDate`, `request`, and `commit` behavior.
3. Replace Mass Flow's single date field with request-state ownership.
4. Ensure `_loadMassForDate` records the request before awaiting and commits only the current successful result.
5. Make the date picker and secondary-language reload target the requested date.
6. Run the new model test and existing latest-request tests.

## Task 2: Preserve installed translations when offline

**Files:**

- Modify: `test/data/services/offline_bible_service_test.dart`
- Modify: `lib/data/services/offline_bible_service.dart`

1. Write a failing service test with an installed approved database and a 503 manifest response.
2. Add an async offline catalog builder that combines bundled sources with validated installed downloadable sources.
3. Route non-200, invalid JSON-shape, and caught request failures through the offline catalog.
4. Use the injected database validator for installed-state checks in tests while retaining strict normalized-schema validation in production.
5. Verify corrupt/raw databases remain excluded.

## Task 3: Recover a stale selected downloaded source

**Files:**

- Modify: `test/data/services/downloaded_bible_backend_test.dart`
- Modify: `lib/data/services/readings_backend_io.dart`

1. Write failing backend tests for a missing selected Douay-Rheims file and an invalid-schema selected file.
2. Validate expected normalized tables after opening downloadable databases.
3. In `_currentBibleDatabase`, catch failures only for downloadable sources, persist RSVCE, and open the bundled fallback.
4. Confirm chapter/book reads return bundled data and the preference is RSVCE.

## Task 4: Focused verification and review

1. Format changed Dart files.
2. Run all new and directly related regression tests.
3. Run `flutter analyze` and `git diff --check`.
4. Request an independent code review and address confirmed issues test-first.

## Task 5: Full verification and integration

1. Run the complete `flutter test` suite.
2. Build an Android debug APK.
3. Commit P2 implementation on `codex/p2-fixes`.
4. Merge the verified branch into local `main` if no blockers remain.
5. Re-run a focused smoke suite on the merge result and report residual risks.

