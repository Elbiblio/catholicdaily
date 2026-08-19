# Catholic Missal for Nigeria Complete Liturgical Psalm Coverage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename the edition to `Catholic Missal for Nigeria` and make every stable Catholic liturgical psalm usage resolve to all valid ordered choices with Nigerian text when verified and clearly labeled fallback text otherwise.

**Architecture:** Add a deterministic stable-usage generator that separates calendar usages from reusable psalm selections and edition-specific texts. Reconcile the generated universe with Nigerian captures, CatholicGallery historical references, the repository lectionary, and installed Bible editions; then expose the ordered usage catalog through the existing Dart resolver while retaining true source labels.

**Tech Stack:** Python 3 CSV/dataclass corpus tools, Flutter/Dart services and asset bundles, unittest, flutter_test, repository lectionary CSVs.

---

## File structure

- Create `scripts/psalm_sources/liturgical_usage_universe.py`: deterministic source-to-stable-usage enumeration and validation.
- Create `scripts/psalm_sources/nigeria_text_reconstruction.py`: exact reuse and verified-fragment reconstruction for Nigerian selection text.
- Create `scripts/build_complete_nigeria_psalm_coverage.py`: orchestration and atomic writing of runtime and verification CSV/JSON artifacts.
- Create `verification/psalm_sources/nigeria_complete_liturgical_coverage.csv`: one row per stable usage and ordered choice.
- Create `verification/psalm_sources/nigeria_complete_liturgical_coverage.json`: exact coverage totals and unresolved/conflict counts.
- Modify `scripts/psalm_sources/source_registry.json`: exact visible edition name.
- Modify `scripts/psalm_sources/nigeria_365.py`: exact visible edition name in extracted source rows.
- Modify `scripts/build_nigeria_psalm_usage_catalog.py`: delegate complete generation to the new orchestrator and retain compatibility entry point.
- Modify `scripts/build_responsorial_psalm_corpus.py`: include reconciled Nigerian pack rows and complete comparison output.
- Modify `assets/data/nigeria_psalm_usages.csv`: generated stable-usage catalog with every ordered choice.
- Modify `assets/data/psalm_editions/nigeria_365.csv`: generated verified Nigerian text rows.
- Modify `assets/data/psalm_editions/manifest.json`: generated exact display name and pack count.
- Modify `verification/psalm_sources/psalm_text_comparison.csv`: complete usage/edition comparison.
- Modify `verification/psalm_sources/psalm_usage_map.csv`: complete stable usage mapping.
- Modify `lib/data/models/liturgical_psalm_usage_context.dart`: stable-key normalization shared by callers.
- Modify `lib/data/services/nigeria_psalm_usage_service.dart`: resolve every ordered usage choice without civil-date dependence.
- Modify `lib/data/services/responsorial_psalm_source_pack_service.dart`: distinguish exact Nigerian, reconstructed Nigerian, and alternate-edition rows.
- Modify `lib/data/services/responsorial_psalm_fallback_service.dart`: preserve actual edition identity throughout fallback.
- Modify `test/scripts/responsorial_psalm_corpus_test.py`: source, universe, reconstruction, coverage, comparison, and naming regressions.
- Modify `test/data/services/nigeria_psalm_usage_service_test.dart`: stable-key and ordered-choice regressions.
- Modify `test/data/services/responsorial_psalm_source_pack_service_test.dart`: edition/provenance and selection regressions.
- Modify `test/data/services/responsorial_psalm_fallback_service_test.dart`: no cross-edition relabeling.
- Modify `test/data/services/nigeria_missal_audit_test.dart`: complete real-asset coverage audit.

### Task 1: Freeze the edition name and current incomplete coverage as RED

**Files:**
- Modify: `test/scripts/responsorial_psalm_corpus_test.py`
- Modify: `test/data/services/responsorial_psalm_source_pack_service_test.dart`

- [ ] **Step 1: Write the failing source-registry name test**

Add to `PsalmSourceRegistryTest`:

```python
def test_nigeria_source_uses_exact_public_name(self):
    raw = json.loads(
        (ROOT / "scripts/psalm_sources/source_registry.json").read_text(
            encoding="utf-8"
        )
    )
    nigeria = next(
        row for row in raw if row["source_id"] == "nigeria_365_firestore"
    )
    self.assertEqual(nigeria["source_name"], "Catholic Missal for Nigeria")
    self.assertNotIn("365 Readings", json.dumps(nigeria))
```

- [ ] **Step 2: Write the failing generated-manifest test**

Add to `PsalmSourcePackTest`:

```python
def test_nigeria_manifest_uses_exact_public_name(self):
    manifest = json.loads(
        (ROOT / "assets/data/psalm_editions/manifest.json").read_text(
            encoding="utf-8"
        )
    )
    nigeria = next(
        row for row in manifest["editions"]
        if row["id"] == "nigeria_365_firestore"
    )
    self.assertEqual(nigeria["displayName"], "Catholic Missal for Nigeria")
```

- [ ] **Step 3: Write the failing real-asset count-separation test**

```python
def test_nigeria_usage_and_text_selection_counts_are_separate(self):
    usage_path = ROOT / "assets/data/nigeria_psalm_usages.csv"
    pack_path = ROOT / "assets/data/psalm_editions/nigeria_365.csv"
    with usage_path.open(encoding="utf-8-sig", newline="") as handle:
        usages = list(csv.DictReader(handle))
    with pack_path.open(encoding="utf-8-sig", newline="") as handle:
        texts = list(csv.DictReader(handle))
    self.assertGreater(len(usages), len(texts))
    self.assertTrue(all(row["usage_id"] for row in usages))
    self.assertTrue(all(row["selection_id"] for row in texts))
```

- [ ] **Step 4: Run RED tests and record the expected failures**

Run:

```powershell
python -m unittest test.scripts.responsorial_psalm_corpus_test.PsalmSourceRegistryTest.test_nigeria_source_uses_exact_public_name test.scripts.responsorial_psalm_corpus_test.PsalmSourcePackTest.test_nigeria_manifest_uses_exact_public_name
```

Expected: FAIL because the current registry and manifest contain `Catholic Missal for Nigeria / 365 Readings`.

- [ ] **Step 5: Commit the RED tests**

```powershell
git add test/scripts/responsorial_psalm_corpus_test.py test/data/services/responsorial_psalm_source_pack_service_test.dart
git commit -m "test: require complete Nigeria psalm coverage"
```

### Task 2: Build the deterministic stable liturgical usage universe

**Files:**
- Create: `scripts/psalm_sources/liturgical_usage_universe.py`
- Modify: `test/scripts/responsorial_psalm_corpus_test.py`

- [ ] **Step 1: Write failing universe tests**

Import the new API and add a test class:

```python
from scripts.psalm_sources.liturgical_usage_universe import (
    build_liturgical_usage_universe,
    validate_liturgical_usage_universe,
)


class LiturgicalUsageUniverseTest(unittest.TestCase):
    def test_universe_covers_cycles_propers_forms_and_alternatives(self):
        rows = validate_liturgical_usage_universe(
            build_liturgical_usage_universe(ROOT)
        )
        self.assertGreater(len({row.stable_key for row in rows}), 1000)
        self.assertEqual(
            {row.sunday_cycle for row in rows if row.sunday_cycle},
            {"A", "B", "C"},
        )
        self.assertEqual(
            {row.weekday_cycle for row in rows if row.weekday_cycle},
            {"I", "II"},
        )
        self.assertTrue(
            any(
                row.celebration_id
                == "the_assumption_of_the_blessed_virgin_mary"
                and row.mass_form == "vigil"
                for row in rows
            )
        )
        self.assertTrue(any(row.choice_priority > 1 for row in rows))
        self.assertTrue(all(not row.date_rule for row in rows))

    def test_universe_has_unique_stable_key_and_priority_pairs(self):
        rows = validate_liturgical_usage_universe(
            build_liturgical_usage_universe(ROOT)
        )
        pairs = [(row.stable_key, row.choice_priority) for row in rows]
        self.assertEqual(len(pairs), len(set(pairs)))
```

- [ ] **Step 2: Run the universe test and verify RED**

```powershell
python -m unittest test.scripts.responsorial_psalm_corpus_test.LiturgicalUsageUniverseTest -v
```

Expected: ERROR with `ModuleNotFoundError` for `liturgical_usage_universe`.

- [ ] **Step 3: Implement the universe row and stable-key contract**

Create `scripts/psalm_sources/liturgical_usage_universe.py` with this public structure:

```python
from __future__ import annotations

from dataclasses import dataclass
import csv
from pathlib import Path
from typing import Iterable


@dataclass(frozen=True)
class LiturgicalUsageTarget:
    territory: str
    kind: str
    reference_normalized: str
    response_text: str
    choice_priority: int
    celebration_id: str = ""
    mass_form: str = ""
    season: str = ""
    week: str = ""
    weekday: str = ""
    special_day: str = ""
    sunday_cycle: str = ""
    weekday_cycle: str = ""
    lectionary_number: str = ""
    source_catalog: str = ""
    date_rule: str = ""

    @property
    def stable_key(self) -> str:
        if self.kind == "temporal":
            values = (
                self.territory, self.kind, self.season, self.week,
                self.weekday, self.sunday_cycle, self.weekday_cycle,
            )
        elif self.kind == "celebration":
            values = (
                self.territory, self.kind, self.celebration_id,
                self.mass_form, self.sunday_cycle, self.weekday_cycle,
            )
        else:
            values = (
                self.territory, self.kind, self.special_day,
                self.mass_form, self.sunday_cycle, self.weekday_cycle,
            )
        return "|".join(values)
```

Implement loaders for `standard_lectionary_complete.csv`, `memorial_feasts.csv`, Nigeria proper identifiers already defined by `nigeria_assignment_rules.py`, and existing reviewed historical usage rows. Normalize every row into `LiturgicalUsageTarget`, assign choice priorities per stable key, and merge exact duplicate reference/response choices.

- [ ] **Step 4: Implement strict validation**

```python
def validate_liturgical_usage_universe(
    rows: Iterable[LiturgicalUsageTarget],
) -> tuple[LiturgicalUsageTarget, ...]:
    result = tuple(rows)
    seen: set[tuple[str, int]] = set()
    for row in result:
        if row.date_rule:
            raise ValueError(f"civil date leaked into stable usage: {row.stable_key}")
        if not row.reference_normalized or not row.response_text:
            raise ValueError(f"incomplete usage choice: {row.stable_key}")
        key = (row.stable_key, row.choice_priority)
        if key in seen:
            raise ValueError(f"duplicate usage choice: {key}")
        seen.add(key)
    return tuple(sorted(result, key=lambda row: (row.stable_key, row.choice_priority)))
```

- [ ] **Step 5: Run the universe tests and make them GREEN**

```powershell
python -m unittest test.scripts.responsorial_psalm_corpus_test.LiturgicalUsageUniverseTest -v
```

Expected: PASS and an exact derived stable-key count printed by the later build task, not encoded as a magic constant.

- [ ] **Step 6: Commit the generator**

```powershell
git add scripts/psalm_sources/liturgical_usage_universe.py test/scripts/responsorial_psalm_corpus_test.py
git commit -m "feat: generate complete liturgical psalm usages"
```

### Task 3: Reconcile CatholicGallery and historical Nigeria evidence

**Files:**
- Create: `scripts/build_complete_nigeria_psalm_coverage.py`
- Modify: `scripts/build_nigeria_psalm_usage_catalog.py`
- Modify: `test/scripts/responsorial_psalm_corpus_test.py`
- Create: `verification/psalm_sources/nigeria_complete_liturgical_coverage.csv`
- Create: `verification/psalm_sources/nigeria_complete_liturgical_coverage.json`

- [ ] **Step 1: Write failing reconciliation tests**

```python
class CompleteNigeriaCoverageTest(unittest.TestCase):
    def test_every_usage_choice_has_provenance_and_resolution_status(self):
        path = ROOT / "verification/psalm_sources/nigeria_complete_liturgical_coverage.csv"
        self.assertTrue(path.exists())
        with path.open(encoding="utf-8-sig", newline="") as handle:
            rows = list(csv.DictReader(handle))
        self.assertGreater(len({row["stable_usage_key"] for row in rows}), 1000)
        self.assertTrue(all(row["reference_normalized"] for row in rows))
        self.assertTrue(all(row["response_text"] for row in rows))
        self.assertTrue(
            all(
                row["resolution_status"]
                in {"exact_nigeria", "reconstructed_nigeria", "fallback", "conflict"}
                for row in rows
            )
        )
        self.assertTrue(all(row["source_catalog"] for row in rows))

    def test_catholicgallery_is_reference_evidence_not_nigeria_text(self):
        path = ROOT / "verification/psalm_sources/nigeria_complete_liturgical_coverage.csv"
        with path.open(encoding="utf-8-sig", newline="") as handle:
            rows = list(csv.DictReader(handle))
        gallery = [row for row in rows if row["gallery_source_url"]]
        self.assertTrue(gallery)
        self.assertTrue(all(row["gallery_text_edition"] == "Douay-Rheims" for row in gallery))
        self.assertTrue(
            all(
                not (
                    row["display_edition"] == "Catholic Missal for Nigeria"
                    and row["text_source_id"] == "catholic_gallery_douay_archive"
                )
                for row in rows
            )
        )
```

- [ ] **Step 2: Run the reconciliation tests and verify RED**

```powershell
python -m unittest test.scripts.responsorial_psalm_corpus_test.CompleteNigeriaCoverageTest -v
```

Expected: FAIL because the complete coverage artifacts do not exist.

- [ ] **Step 3: Implement deterministic evidence matching**

In `build_complete_nigeria_psalm_coverage.py`, load:

```python
def load_csv_rows(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def load_nigeria_pack(path: Path) -> list[RuntimePsalmPackRow]:
    return [
        RuntimePsalmPackRow(
            edition_id=row["edition_id"],
            selection_id=row["selection_id"],
            territory=row["territory"],
            celebration_id=row["celebration_id"],
            date_rule=row["date_rule"],
            reading_set_kind=row["reading_set_kind"],
            sunday_cycle=row["sunday_cycle"],
            weekday_cycle=row["weekday_cycle"],
            lectionary_number=row["lectionary_number"],
            reference_normalized=row["reference_normalized"],
            response_text=row["response_text"],
            stanzas_text=row["stanzas_text"],
            source_url=row["source_url"],
            source_edition=row["source_edition"],
            display_priority=int(row["display_priority"]),
        )
        for row in load_csv_rows(path)
    ]


universe = validate_liturgical_usage_universe(
    build_liturgical_usage_universe(ROOT)
)
current = load_nigeria_pack(ROOT / "assets/data/psalm_editions/nigeria_365.csv")
history = load_csv_rows(
    ROOT / "verification/psalm_sources/nigeria_2024_2025_usage_assignments.csv"
)
gallery = [
    row
    for row in load_csv_rows(
        ROOT / "verification/psalm_sources/nigeria_2024_2025_psalms.csv"
    )
    if row["source_id"] == "catholic_gallery_douay_archive"
]
```

Match evidence in this order: stable key plus exact normalized reference and response; stable key plus exact numbered selection; reference plus normalized response; reference-only comparison. Reference-only evidence may establish calendar coverage but cannot establish Nigerian wording.

- [ ] **Step 4: Atomically write the complete audit artifacts**

Write CSV fields:

```python
COVERAGE_FIELDS = (
    "stable_usage_key", "choice_priority", "territory", "kind",
    "celebration_id", "mass_form", "season", "week", "weekday",
    "special_day", "sunday_cycle", "weekday_cycle", "lectionary_number",
    "reference_normalized", "response_text", "source_catalog",
    "nigeria_selection_id", "nigeria_source_date", "gallery_source_url",
    "gallery_text_edition", "rsvce_selection_id", "text_source_id",
    "display_edition", "resolution_status", "review_notes",
)
```

The JSON summary records exact counts for stable usages, ordered choices, distinct references, responses, exact Nigerian texts, reconstructed Nigerian texts, fallbacks, and conflicts.

- [ ] **Step 5: Make the reconciliation tests GREEN**

```powershell
python scripts/build_complete_nigeria_psalm_coverage.py
python -m unittest test.scripts.responsorial_psalm_corpus_test.CompleteNigeriaCoverageTest -v
```

Expected: PASS; every universe row appears once per choice and CatholicGallery remains labeled Douay-Rheims.

- [ ] **Step 6: Commit reconciliation**

```powershell
git add scripts/build_complete_nigeria_psalm_coverage.py scripts/build_nigeria_psalm_usage_catalog.py verification/psalm_sources/nigeria_complete_liturgical_coverage.csv verification/psalm_sources/nigeria_complete_liturgical_coverage.json test/scripts/responsorial_psalm_corpus_test.py
git commit -m "feat: reconcile complete Nigeria psalm usage coverage"
```

### Task 4: Expand Nigerian text selections with exact reuse and verified reconstruction

**Files:**
- Create: `scripts/psalm_sources/nigeria_text_reconstruction.py`
- Modify: `scripts/build_complete_nigeria_psalm_coverage.py`
- Modify: `assets/data/psalm_editions/nigeria_365.csv`
- Modify: `test/scripts/responsorial_psalm_corpus_test.py`

- [ ] **Step 1: Write failing reconstruction tests**

```python
from scripts.build_complete_nigeria_psalm_coverage import load_nigeria_pack
from scripts.psalm_sources.nigeria_text_reconstruction import (
    build_verified_fragment_index,
    reconstruct_nigeria_selection,
)


class NigeriaTextReconstructionTest(unittest.TestCase):
    def test_exact_selection_is_preferred_to_fragment_reconstruction(self):
        rows = load_nigeria_pack(ROOT / "assets/data/psalm_editions/nigeria_365.csv")
        exact = rows[0]
        result = reconstruct_nigeria_selection(
            exact.reference_normalized,
            exact.response_text,
            rows,
            build_verified_fragment_index(rows),
        )
        self.assertEqual(result.status, "exact_nigeria")
        self.assertEqual(result.stanzas_text, exact.stanzas_text)

    def test_incomplete_or_conflicting_fragments_do_not_create_nigeria_text(self):
        result = reconstruct_nigeria_selection(
            "ps999:1-4",
            "A response.",
            (),
            {},
        )
        self.assertEqual(result.status, "fallback")
        self.assertEqual(result.stanzas_text, "")
```

- [ ] **Step 2: Run reconstruction tests and verify RED**

```powershell
python -m unittest test.scripts.responsorial_psalm_corpus_test.NigeriaTextReconstructionTest -v
```

Expected: ERROR because the reconstruction module does not exist.

- [ ] **Step 3: Implement fragment indexing and reconstruction**

Create immutable results:

```python
@dataclass(frozen=True)
class NigeriaTextResolution:
    status: str
    stanzas_text: str
    source_selection_ids: tuple[str, ...]
    notes: str = ""
```

Index fragments by normalized biblical book, chapter, verse number, and letter suffix. Accept a fragment only when every observed Nigerian rendering for that exact fragment normalizes to the same words. Reconstruct only when all requested fragments are available in lectionary order; otherwise return `fallback` with no Nigerian stanza text.

- [ ] **Step 4: Generate the expanded Nigerian pack**

For each required distinct selection, emit a Nigerian pack row only for `exact_nigeria` or `reconstructed_nigeria`. Preserve its true Nigerian source IDs and provenance in the coverage artifact. Do not emit CatholicGallery or RSVCE text under `nigeria_365_firestore`.

- [ ] **Step 5: Add pack-integrity assertions**

```python
def test_every_nigeria_pack_row_has_complete_verified_text(self):
    path = ROOT / "assets/data/psalm_editions/nigeria_365.csv"
    with path.open(encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    self.assertTrue(rows)
    self.assertTrue(all(row["edition_id"] == "nigeria_365_firestore" for row in rows))
    self.assertTrue(all(row["response_text"].strip() for row in rows))
    self.assertTrue(all(row["stanzas_text"].strip() for row in rows))
    self.assertEqual(len(rows), len({row["selection_id"] for row in rows}))
```

- [ ] **Step 6: Run and commit**

```powershell
python scripts/build_complete_nigeria_psalm_coverage.py
python -m unittest test.scripts.responsorial_psalm_corpus_test.NigeriaTextReconstructionTest test.scripts.responsorial_psalm_corpus_test.PsalmSourcePackTest -v
git add scripts/psalm_sources/nigeria_text_reconstruction.py scripts/build_complete_nigeria_psalm_coverage.py assets/data/psalm_editions/nigeria_365.csv test/scripts/responsorial_psalm_corpus_test.py
git commit -m "feat: expand verified Nigeria psalm selections"
```

### Task 5: Generate the complete runtime usage catalog and order proper choices first

**Files:**
- Modify: `assets/data/nigeria_psalm_usages.csv`
- Modify: `lib/data/models/liturgical_psalm_usage_context.dart`
- Modify: `lib/data/services/nigeria_psalm_usage_service.dart`
- Modify: `test/data/services/nigeria_psalm_usage_service_test.dart`
- Modify: `test/data/services/nigeria_missal_audit_test.dart`

- [ ] **Step 1: Write failing stable-context and ordering tests**

```dart
test('all complete-catalog choices resolve without civil dates', () async {
  final raw = await rootBundle.loadString('assets/data/nigeria_psalm_usages.csv');
  final entries = NigeriaPsalmUsageService.parseCsv(raw);
  expect(entries, isNotEmpty);
  expect(entries.every((entry) => entry.sourceDate.isNotEmpty), isTrue);
  expect(entries.every((entry) => !entry.stableKey.contains(entry.sourceDate)), isTrue);
  final pairs = entries.map((entry) => '${entry.stableKey}|${entry.choicePriority}').toList();
  expect(pairs.toSet(), hasLength(pairs.length));
});

test('proper feast choice is first and alternatives remain accessible', () {
  const context = LiturgicalPsalmUsageContext.celebration(
    territory: 'NG',
    celebrationId: 'the_assumption_of_the_blessed_virgin_mary',
    massForm: 'day',
  );
  final choices = service.resolve(context);
  expect(choices, isNotEmpty);
  expect(choices.first.choicePriority, 1);
  final priorities = choices.map((entry) => entry.choicePriority).toList();
  expect(priorities, orderedEquals((<int>[...priorities]..sort())));
  expect(choices.length, greaterThan(1));
});
```

- [ ] **Step 2: Run the Dart tests and verify RED**

```powershell
flutter test --no-pub test/data/services/nigeria_psalm_usage_service_test.dart test/data/services/nigeria_missal_audit_test.dart
```

Expected: FAIL because the current catalog covers only 775 rows and does not enumerate every generated choice.

- [ ] **Step 3: Generate `nigeria_psalm_usages.csv` from the universe**

Convert every coverage row into the existing CSV schema. Set `usage_id` from a slug plus choice priority, retain civil `source_date` only as provenance, and sort by stable key then choice priority. The generator must fail on any missing stable usage or duplicate key/priority pair.

- [ ] **Step 4: Normalize Dart stable keys through one model implementation**

Move all string canonicalization into `LiturgicalPsalmUsageContext.stableKey`. `NigeriaPsalmUsageEntry.stableKey` must construct the same context and delegate to it instead of maintaining a second format.

- [ ] **Step 5: Return every ordered choice**

Ensure `NigeriaPsalmUsageService.resolve` filters by the exact stable key and sorts by `choicePriority`, then `usageId`. Do not filter out temporal or Common alternatives after a proper has matched.

- [ ] **Step 6: Make tests GREEN and commit**

```powershell
python scripts/build_complete_nigeria_psalm_coverage.py
flutter test --no-pub test/data/services/nigeria_psalm_usage_service_test.dart test/data/services/nigeria_missal_audit_test.dart
git add assets/data/nigeria_psalm_usages.csv lib/data/models/liturgical_psalm_usage_context.dart lib/data/services/nigeria_psalm_usage_service.dart test/data/services/nigeria_psalm_usage_service_test.dart test/data/services/nigeria_missal_audit_test.dart
git commit -m "feat: resolve every Nigeria liturgical psalm usage"
```

### Task 6: Preserve edition identity through pack lookup and fallback

**Files:**
- Modify: `lib/data/services/responsorial_psalm_source_pack_service.dart`
- Modify: `lib/data/services/responsorial_psalm_fallback_service.dart`
- Modify: `test/data/services/responsorial_psalm_source_pack_service_test.dart`
- Modify: `test/data/services/responsorial_psalm_fallback_service_test.dart`

- [ ] **Step 1: Write failing fallback-label tests**

```dart
test('missing Nigeria text keeps the actual fallback edition label', () async {
  final result = await fallback.resolve(
    request: ResponsorialPsalmRequest(
      selectedEditionId: 'nigeria_365_firestore',
      reference: request.reference,
      responseText: request.responseText,
      date: request.date,
      territory: request.territory,
      celebrationId: request.celebrationId,
      readingSetKind: request.readingSetKind,
      sundayCycle: request.sundayCycle,
      weekdayCycle: request.weekdayCycle,
      lectionaryNumber: request.lectionaryNumber,
    ),
    territoryEditionId: 'nigeria_365_firestore',
    bibleEditionId: 'local_nabre',
  );
  expect(result.requestedEditionId, 'nigeria_365_firestore');
  expect(result.actualEditionId, 'local_nabre');
  expect(result.actualEditionName, 'NABRE');
  expect(result.fallbackReason, PsalmFallbackReason.selectedEditionMissing);
});
```

- [ ] **Step 2: Run and verify RED**

```powershell
flutter test --no-pub test/data/services/responsorial_psalm_source_pack_service_test.dart test/data/services/responsorial_psalm_fallback_service_test.dart
```

Expected: FAIL wherever the current fallback reason or displayed source identity is inferred from the requested territory edition.

- [ ] **Step 3: Tighten lookup scoring**

Score exact stable selection ID, celebration, form, cycle, normalized reference, and response ahead of generic same-reference rows. Treat all Nigeria source dates as provenance, but never let a row with a different response outrank the usage-selected response.

- [ ] **Step 4: Preserve actual edition metadata**

Construct `ResolvedResponsorialPsalm` exclusively from the registry record for the entry that supplied stanza text. Keep `requestedEditionId` separate, and set `fallbackReason` whenever actual and requested editions differ, including territory-lectionary requests.

- [ ] **Step 5: Make tests GREEN and commit**

```powershell
flutter test --no-pub test/data/services/responsorial_psalm_source_pack_service_test.dart test/data/services/responsorial_psalm_fallback_service_test.dart
git add lib/data/services/responsorial_psalm_source_pack_service.dart lib/data/services/responsorial_psalm_fallback_service.dart test/data/services/responsorial_psalm_source_pack_service_test.dart test/data/services/responsorial_psalm_fallback_service_test.dart
git commit -m "fix: preserve psalm edition identity through fallback"
```

### Task 7: Regenerate manifests and comparison CSVs

**Files:**
- Modify: `scripts/psalm_sources/source_registry.json`
- Modify: `scripts/psalm_sources/nigeria_365.py`
- Modify: `scripts/build_responsorial_psalm_corpus.py`
- Modify: `assets/data/psalm_editions/manifest.json`
- Modify: `verification/psalm_sources/psalm_text_comparison.csv`
- Modify: `verification/psalm_sources/psalm_usage_map.csv`
- Modify: `test/scripts/responsorial_psalm_corpus_test.py`

- [ ] **Step 1: Replace the public source name**

Change every generated/public `source_name` and `displayName` value from `Catholic Missal for Nigeria / 365 Readings` to `Catholic Missal for Nigeria`. Keep the source ID `nigeria_365_firestore` and pack filename stable.

- [ ] **Step 2: Add comparison completeness tests**

```python
def test_complete_comparison_has_all_usages_and_two_comparable_text_columns(self):
    def rows(path):
        with path.open(encoding="utf-8-sig", newline="") as handle:
            return list(csv.DictReader(handle))

    coverage = rows(
        ROOT / "verification/psalm_sources/nigeria_complete_liturgical_coverage.csv"
    )
    comparison = rows(
        ROOT / "verification/psalm_sources/psalm_text_comparison.csv"
    )
    expected = {
        (row["stable_usage_key"], row["choice_priority"])
        for row in coverage
    }
    actual = {
        (row["stable_usage_key"], row["choice_priority"])
        for row in comparison
    }
    self.assertEqual(actual, expected)
    self.assertTrue(
        all(
            row["nigeria_text"] or row["fallback_text"]
            for row in comparison
        )
    )
    self.assertTrue(all(row["rsvce_text"] for row in comparison))
```

- [ ] **Step 3: Run the comparison test and verify RED**

```powershell
python -m unittest test.scripts.responsorial_psalm_corpus_test.CompleteNigeriaCoverageTest.test_complete_comparison_has_all_usages_and_two_comparable_text_columns -v
```

Expected: FAIL because the existing comparison is selection-centric and lacks every stable usage/choice.

- [ ] **Step 4: Generate the complete long-form comparison**

Join coverage rows to Nigerian, CatholicGallery/Douay-Rheims, RSVCE, and NABRE pack rows by normalized selection. Retain full text in separate columns and include actual source IDs. Never fill `nigeria_text` from another edition.

- [ ] **Step 5: Regenerate and validate all artifacts**

```powershell
python scripts/build_complete_nigeria_psalm_coverage.py
python scripts/build_responsorial_psalm_corpus.py --fixtures-only
python -m unittest test.scripts.responsorial_psalm_corpus_test -v
```

Expected: PASS; generated manifest name is exact, pack counts match their CSVs, and comparison coverage equals the complete universe.

- [ ] **Step 6: Commit generated outputs**

```powershell
git add scripts/psalm_sources/source_registry.json scripts/psalm_sources/nigeria_365.py scripts/build_responsorial_psalm_corpus.py assets/data/psalm_editions/manifest.json verification/psalm_sources/psalm_text_comparison.csv verification/psalm_sources/psalm_usage_map.csv test/scripts/responsorial_psalm_corpus_test.py
git commit -m "data: publish complete Nigeria psalm coverage"
```

### Task 8: Corpus-wide and UI verification

**Files:**
- Modify only if a failing regression proves a defect in files already listed above.

- [ ] **Step 1: Verify no stale public label remains**

```powershell
rg -n -i "Catholic Missal for Nigeria / 365 Readings|365 Readings" assets lib scripts test verification
```

Expected: no user-visible or generated source-name matches; references in historical explanatory prose must be reviewed and renamed when they describe the same source.

- [ ] **Step 2: Run Python corpus tests**

```powershell
python -m unittest test.scripts.responsorial_psalm_corpus_test test.scripts.standard_lectionary_builder_test -v
```

Expected: PASS.

- [ ] **Step 3: Run focused Flutter tests**

```powershell
flutter test --no-pub test/data/services/nigeria_psalm_usage_service_test.dart test/data/services/nigeria_missal_audit_test.dart test/data/services/responsorial_psalm_source_pack_service_test.dart test/data/services/responsorial_psalm_fallback_service_test.dart test/data/services/responsorial_psalm_runtime_integrity_test.dart test/data/services/resolver_incipit_refrain_audit_test.dart test/data/services/full_corpus_incipit_audit_test.dart
```

Expected: PASS.

- [ ] **Step 4: Run static analysis**

```powershell
flutter analyze --no-pub
```

Expected: `No issues found!`

- [ ] **Step 5: Run the serialized full test suite**

```powershell
flutter test --no-pub --concurrency=1
```

Expected: all tests pass; only previously documented skips remain.

- [ ] **Step 6: Build Windows and inspect the edition selector**

```powershell
flutter build windows --debug --no-pub
flutter run -d windows --no-pub
```

Verify on representative ordinary weekdays, Sunday cycles A/B/C, weekday cycles I/II, Assumption vigil/day, a memorial with alternatives, Holy Week, Easter Octave, and a Nigerian proper. Confirm that every choice is available, the proper choice is first, and the displayed edition label matches the actual stanza source.

- [ ] **Step 7: Perform final data assertions**

```powershell
python scripts/build_complete_nigeria_psalm_coverage.py --check
git diff --check
git status --short
```

Expected: generated artifacts are reproducible, there are no whitespace errors, and the status contains only the intended implementation paths plus preserved pre-existing user work.

- [ ] **Step 8: Commit the verified release state**

```powershell
git add assets/data/nigeria_psalm_usages.csv assets/data/psalm_editions/nigeria_365.csv assets/data/psalm_editions/manifest.json verification/psalm_sources/nigeria_complete_liturgical_coverage.csv verification/psalm_sources/nigeria_complete_liturgical_coverage.json verification/psalm_sources/psalm_text_comparison.csv verification/psalm_sources/psalm_usage_map.csv
git commit -m "test: verify complete Nigeria liturgical psalm coverage"
```
