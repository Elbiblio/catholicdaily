# Liturgical Psalm Usage Resolution Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Gregorian-date psalm selection with stable temporal, celebration, and Mass-form usage resolution while preserving source-date provenance and edition fallback.

**Architecture:** A dedicated Nigerian usage catalog selects references and responses by a `LiturgicalPsalmUsageContext`; the edition packs render the selected text independently. The daily resolver passes an explicit context for each primary, temporal, memorial, vigil, and named Mass set, so choices from one set cannot leak into another.

**Tech Stack:** Flutter/Dart services and tests, Python corpus-generation tools, CSV runtime assets, existing Ordo and reading catalogs.

**Release constraint:** Do not commit or push until every task and final verification step passes.

---

## File structure

- Create `lib/data/models/liturgical_psalm_usage_context.dart`: immutable stable usage key.
- Create `lib/data/services/nigeria_psalm_usage_service.dart`: loads and matches the Nigerian usage catalog.
- Create `assets/data/nigeria_psalm_usages.csv`: generated stable usage assignments with source-date provenance.
- Create `scripts/psalm_sources/nigeria_usage_catalog.py`: validates and writes stable usages.
- Modify `scripts/psalm_sources/source_packs.py`: make Nigerian text rows generic by reference rather than date-selected.
- Modify `lib/data/services/csv_readings_resolver_service.dart`: remove date overlay and apply a context to each reading-set construction path.
- Modify `lib/data/services/responsorial_psalm_source_pack_service.dart`: remove exact-date selection from text lookup.
- Modify `test/data/services/nigeria_missal_audit_test.dart`: verify temporal and proper recurrence semantics.
- Create `test/data/services/nigeria_psalm_usage_service_test.dart`: focused matching/precedence tests.
- Modify `test/data/services/responsorial_psalm_runtime_integrity_test.dart`: verify every usage across installed text editions/fallback.
- Modify `test/scripts/responsorial_psalm_corpus_test.py`: generator ambiguity and completeness tests.

### Task 1: Establish the stable usage API with failing tests

**Files:**
- Create: `test/data/services/nigeria_psalm_usage_service_test.dart`
- Create later: `lib/data/models/liturgical_psalm_usage_context.dart`
- Create later: `lib/data/services/nigeria_psalm_usage_service.dart`

- [ ] **Step 1: Write the failing temporal recurrence test**

Define two dates with the same Ordinary Time week, weekday, and weekday cycle but different Gregorian years. Request the wished-for API:

```dart
final context = LiturgicalPsalmUsageContext.temporal(
  territory: 'NG',
  season: 'ordinary_time',
  week: 20,
  weekday: DateTime.tuesday,
  weekdayCycle: 'II',
);
final choices = await service.resolve(context);
expect(choices.single.referenceNormalized, startsWith('deut32:'));
```

- [ ] **Step 2: Write failing cycle-isolation and proper-precedence tests**

```dart
expect(
  await service.resolve(context.copyWith(weekdayCycle: 'I')),
  isEmpty,
);
final proper = LiturgicalPsalmUsageContext.celebration(
  territory: 'NG',
  celebrationId: 'the_assumption_of_the_blessed_virgin_mary',
  massForm: 'day',
);
expect((await service.resolve(proper)).first.referenceNormalized, 'ps45:10,11,12,16');
```

- [ ] **Step 3: Run RED**

Run:

```powershell
flutter test --no-pub test/data/services/nigeria_psalm_usage_service_test.dart
```

Expected: compilation failure because the context and service do not exist.

### Task 2: Implement the context model and matcher

**Files:**
- Create: `lib/data/models/liturgical_psalm_usage_context.dart`
- Create: `lib/data/services/nigeria_psalm_usage_service.dart`
- Modify: `lib/data/models/responsorial_psalm_text_entry.dart`

- [ ] **Step 1: Implement the immutable key**

The model must expose `territory`, `kind`, `celebrationId`, `massForm`, `season`, `week`, `weekday`, `specialDay`, `sundayCycle`, and `weekdayCycle`. Constructors enforce either celebration or temporal fields, never both.

```dart
enum LiturgicalPsalmUsageKind { temporal, celebration, specialPeriod }

class LiturgicalPsalmUsageContext {
  final String territory;
  final LiturgicalPsalmUsageKind kind;
  final String celebrationId;
  final String massForm;
  final String season;
  final int? week;
  final int? weekday;
  final String specialDay;
  final String sundayCycle;
  final String weekdayCycle;
  // const named constructors, copyWith, equality, and hashCode
}
```

- [ ] **Step 2: Implement exact matching and priority**

The service parses usage rows and matches every non-empty key field. It sorts by `choice_priority`, then `usage_id`. Celebration contexts never consider temporal rows; temporal contexts never consider celebration rows.

- [ ] **Step 3: Run GREEN**

Run the Task 1 command. Expected: all focused matcher tests pass.

### Task 3: Generate stable Nigerian usage assignments

**Files:**
- Create: `scripts/psalm_sources/nigeria_usage_catalog.py`
- Create: `assets/data/nigeria_psalm_usages.csv`
- Modify: `test/scripts/responsorial_psalm_corpus_test.py`
- Modify: `scripts/build_responsorial_psalm_corpus.py`

- [ ] **Step 1: Write failing generator tests**

Test that:

- source dates are retained only in `source_date`;
- temporal keys require season/week/weekday and the applicable cycle;
- celebration keys require celebration ID and Mass form;
- identical text may have multiple usage rows;
- one source choice cannot map to two incompatible keys;
- all 379 imported choices have exactly one reviewed disposition: stable usage or explicit comparison-only exclusion.

- [ ] **Step 2: Run RED**

```powershell
python test/scripts/responsorial_psalm_corpus_test.py
```

Expected: failures for the missing usage catalog generator.

- [ ] **Step 3: Implement the catalog schema**

Use these columns:

```text
usage_id,territory,kind,celebration_id,mass_form,season,week,weekday,
special_day,sunday_cycle,weekday_cycle,reference_normalized,response_text,
source_date,source_selection_id,choice_priority,review_status
```

Reject a row unless `review_status=verified` and its key is structurally complete. Keep exact source dates out of matcher fields.

- [ ] **Step 4: Reconcile imported choices**

Use the application calendar/exported context for the source date and identify each source choice's actual reading set. Handle the six multi-choice dates explicitly by Mass form/set identity. Do not infer unsupported Sunday or weekday cycles.

- [ ] **Step 5: Run GREEN and inspect the catalog**

Run the Python suite, then assert no duplicate `usage_id`, no ambiguous stable key/priority, and no unreviewed display row.

### Task 4: Make text packs date-independent

**Files:**
- Modify: `scripts/psalm_sources/source_packs.py`
- Modify: `lib/data/services/responsorial_psalm_source_pack_service.dart`
- Modify: `test/data/services/responsorial_psalm_source_pack_service_test.dart`

- [ ] **Step 1: Write failing lookup tests**

Prove the same normalized selection renders on two different Gregorian dates and that date alone cannot select a different reference or response.

- [ ] **Step 2: Run RED**

```powershell
flutter test --no-pub test/data/services/responsorial_psalm_source_pack_service_test.dart
```

Expected: the exact-date filter prevents recurrence.

- [ ] **Step 3: Remove date selection from text lookup**

Text lookup filters by normalized reference and compatible territory/edition. Usage matching stays exclusively in `NigeriaPsalmUsageService`. Retain the source date only in provenance fields outside the text key.

- [ ] **Step 4: Run GREEN**

Run the source-pack tests and Python generator tests.

### Task 5: Integrate semantic usage into every reading-set path

**Files:**
- Modify: `lib/data/services/csv_readings_resolver_service.dart`
- Modify: `lib/data/services/alternate_readings_service.dart` only if explicit context cannot be passed through the existing resolver methods.
- Modify: `test/data/services/nigeria_missal_audit_test.dart`

- [ ] **Step 1: Write failing resolver tests**

Cover:

- Tuesday, Week 20, Year II resolves `Dt 32` regardless of Gregorian date;
- Year I does not receive that Year II usage;
- Assumption day proper is first after transfer;
- Assumption vigil remains separate;
- a weekday and optional memorial on the same date do not exchange psalms;
- Easter Vigil alternatives remain attached to their respective reading positions;
- non-Nigerian regions do not consult the Nigerian catalog.

- [ ] **Step 2: Run RED**

Run the Nigeria audit and confirm the current dated overlay fails recurrence/set-isolation assertions.

- [ ] **Step 3: Delete the dated overlay**

Remove `_applyNigeriaDatedPsalmChoices`, `entriesForDate`, and every call that imports all source-date choices into a flat list.

- [ ] **Step 4: Apply explicit contexts**

At each resolver path, construct the correct context and apply only its returned choices:

- primary resolved celebration: celebration ID and day form;
- normal weekday/Sunday: temporal season/week/weekday/cycle;
- optional memorial: its celebration ID;
- vigil/night/dawn: celebration ID and exact Mass form;
- Easter Vigil/special periods: explicit special-period key.

Insert alternatives immediately after that set's primary psalm and preserve source priority.

- [ ] **Step 5: Run GREEN**

Run the Nigeria audit, reading-choice tests, and UI choice test.

### Task 6: Exhaustive selection and rendering audit

**Files:**
- Modify: `test/data/services/responsorial_psalm_runtime_integrity_test.dart`
- Modify: `test/data/services/nigeria_missal_audit_test.dart`

- [ ] **Step 1: Replace the 365-date self-comparison**

Audit every verified stable usage key instead. Resolve a representative date for that key, assert the exact reference/response/order, and assert the same result on another compatible recurrence where one exists.

- [ ] **Step 2: Audit every installed edition/fallback**

For each verified usage and every `registry.selectable` edition, assert non-empty text, unchanged normalized reference, and unchanged response. The actual edition may differ only when fallback is declared.

- [ ] **Step 3: Verify unsupported keys fail safely**

An unsupported cycle retains the existing standard or memorial psalm; it must not borrow a dated Nigerian row.

### Task 7: Final verification without commit or push

**Files:**
- Review all modified files and generated assets.

- [ ] **Step 1: Format and run focused suites**

```powershell
dart format lib test
python test/scripts/responsorial_psalm_corpus_test.py
flutter test --no-pub test/data/services/nigeria_psalm_usage_service_test.dart test/data/services/responsorial_psalm_source_pack_service_test.dart test/data/services/responsorial_psalm_runtime_integrity_test.dart test/data/services/nigeria_missal_audit_test.dart test/data/services/reading_choices_resolver_test.dart test/ui/screens/premium_browse_reading_choices_test.dart
```

- [ ] **Step 2: Run static and full verification**

```powershell
flutter analyze
flutter test --no-pub --concurrency=1
git diff --check
```

Expected: no analyzer issues, no failed tests, and no diff errors.

- [ ] **Step 3: Audit scope and generated files**

Confirm no generated Windows plugin files, unrelated CSVs, temporary artifacts, version files, or user-owned untracked files changed.

- [ ] **Step 4: Report evidence**

Report stable usage counts, excluded/unsupported cycles, recurrence results, edition/fallback matrix, exact test totals, and the uncommitted diff. Do not commit or push without renewed user authorization.
