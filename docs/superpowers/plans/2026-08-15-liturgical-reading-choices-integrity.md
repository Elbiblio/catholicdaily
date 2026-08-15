# Liturgical Reading Choices Integrity Implementation Plan

**Goal:** Replace the competing feast/memorial alternate-reading paths with one rank-aware ordered choice resolver, correct catalog corruption, and prove feast-first accuracy across regions and years.

**Architecture:** Keep `OrdoResolverService` as the calendar authority and `CsvReadingsResolverService` as the canonical reference resolver. Add an ordered reading-choice layer that receives the resolved day, obtains the proper celebration set first, and appends labeled Vigil, weekday, memorial, and common choices without reconstructing scripture references from UI-specific hard-coded data. Validate every catalog field semantically and route `PremiumBrowseScreen` through the single choice result.

**Tech stack:** Flutter/Dart, `flutter_test`, existing offline Ordo/calendar services, CSV reading catalogs, local Bible hydration.

---

## Task 1: Capture the Defect with RED Tests

**Files:**

- Create or modify: `test/data/services/reading_choices_resolver_test.dart`
- Modify: `test/data/services/liturgical_region_rules_test.dart`
- Modify: `test/data/services/st_mark_april25_test.dart`

1. Add exact-reference assertions for the Assumption Day set on Nigeria 2026-08-15.
2. Assert the primary set is first and labeled as the resolved solemnity.
3. Assert Vigil and weekday access follow the primary set.
4. Assert transferred 2026 Assumption dates in England/Wales and Brazil resolve to the same proper set.
5. Add a feast collision regression proving a fixed-date/weekday option cannot precede the feast.
6. Run the focused tests and confirm failures reflect current orchestration, not fixture errors.

## Task 2: Add the Canonical Reading Choice Model

**Files:**

- Create: `lib/data/models/liturgical_reading_choice.dart`
- Create: `lib/data/services/liturgical_reading_choices_service.dart`
- Test: `test/data/services/reading_choices_resolver_test.dart`

1. Model ordered full reading sets and per-slot alternatives.
2. Resolve `LiturgicalDay` and year variables once per request.
3. Build the resolved celebration set through the canonical CSV resolver.
4. Add separately labeled Vigil/authorized full sets when present.
5. Add the weekday set and optional memorial/common choices after the primary set.
6. Deduplicate identical sets without losing meaningful liturgical labels.
7. Make all new focused tests pass.

## Task 3: Remove UI-Specific Reading Reconstruction

**Files:**

- Modify: `lib/data/services/alternate_readings_service.dart`
- Modify: `lib/ui/screens/premium_browse_screen.dart`
- Modify: `lib/data/services/optional_memorial_service.dart`
- Test: `test/ui/screens/premium_browse_screen_test.dart` or the closest existing reading-screen test

1. Adapt or replace `AlternateReadingsService` so it delegates to the canonical choice service.
2. Stop `PremiumBrowseScreen` from independently selecting a feast using the optional-memorial map.
3. Render the first ordered set by default.
4. Expose every additional set through clear choice controls.
5. Keep per-slot alternative cards grouped under the correct reading position.
6. Add UI tests for Assumption primary content and accessible additional choices.

## Task 4: Validate and Repair the Catalog

**Files:**

- Modify: `memorial_feasts.csv`
- Modify when source-verified: `lib/data/services/csv_readings_resolver_service.dart`
- Modify or remove duplicated reference rows: `lib/data/services/optional_memorial_service.dart`
- Create: `test/data/services/memorial_readings_catalog_integrity_test.dart`

1. Parse every memorial row and validate that each field contains the expected data type and scripture slot.
2. Reject response prose in reference fields, references in response-only fields, incipits in alternative-reference fields, empty required fields, duplicate primary/alternative values, and rank-incomplete feast sets.
3. Compare duplicate catalog entries and canonical overrides; choose one reviewed authority.
4. Verify every correction against an official or traceable lectionary reference source.
5. Remove unverified invented propers rather than guessing.
6. Run the entire catalog integrity test until clean.

## Task 5: Exhaustive Calendar Matrix

**Files:**

- Modify: `test/data/services/comprehensive_audit_matrix.dart`
- Modify: `test/data/services/comprehensive_resolver_audit_test.dart`
- Modify: `test/data/services/nigeria_missal_audit_test.dart`

1. Enumerate all solemnities, feasts, obligatory memorials, optional memorials, and movable celebrations represented by production data.
2. Exercise supported regions across enough years to cover Sunday cycles A/B/C, weekday cycles I/II, transfers, and collisions.
3. Assert the resolved celebration set is first and rank-complete.
4. Assert all emitted alternatives are valid, labeled, nonempty, and attached to the correct slot.
5. Assert no fixed-date catalog entry overrides a transferred or higher-ranking celebration.
6. Generate a deterministic mismatch report for any unverified catalog record.

## Task 6: Verification and Release

1. Run focused reading-choice, region, Nigeria, catalog, and UI tests.
2. Run `dart format` on changed Dart files and `flutter analyze`.
3. Run the full Flutter suite serially.
4. Run `git diff --check` and verify only intentional files changed; preserve all user-owned untracked artifacts.
5. Exercise Assumption and representative memorial/feast collisions in the emulator.
6. Review the final diff for source accuracy and rank behavior.
7. Commit and push the urgent fix only after all gates pass.
