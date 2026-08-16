# Responsorial Psalm Edition Packs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build complete multi-edition responsorial psalm comparison data and let users select one responsorial psalm edition independently from the Bible edition, with labeled deterministic fallback.

**Architecture:** Extend the existing Python corpus pipeline to produce a canonical long-form edition corpus, a wide full-text comparison CSV, a usage map, and normalized runtime packs. Add a Dart psalm-edition registry and preference, then resolve each responsorial psalm through selected edition, territory lectionary, selected Bible, and RSVCE while preserving the authoritative liturgical selection and response.

**Tech Stack:** Flutter/Dart, SharedPreferences, SQLite Bible assets, Python 3 CSV/SQLite/HTTP tooling, JSON manifests, `@oai/artifact-tool` for final CSV inspection, Flutter widget/service tests.

---

## File Structure

### Corpus pipeline

- Create `scripts/psalm_sources/bible_databases.py`: extract selected verses from repository and downloaded SQLite Bible databases.
- Create `scripts/psalm_sources/edition_corpus.py`: reconcile edition rows, generate selection IDs, and build wide comparison records.
- Create `scripts/psalm_sources/source_packs.py`: serialize and validate runtime source packs and their manifest.
- Modify `scripts/psalm_sources/models.py`: add edition-text, comparison, usage-map, and pack models.
- Modify `scripts/psalm_sources/source_registry.json`: record renderability, pack ID, source kind, coverage, and fallback role.
- Modify `scripts/psalm_sources/nigeria_365.py`: retain full response/stanza text in the local canonical corpus.
- Modify `scripts/psalm_sources/modern_psalter.py`: extract full available response/stanza text and provenance rather than metadata alone.
- Modify `scripts/build_responsorial_psalm_corpus.py`: emit the long corpus, wide comparison, usage map, runtime packs, and audit report.
- Modify `test/scripts/responsorial_psalm_corpus_test.py`: enforce full-text, reconciliation, hashing, and minimum-two-edition contracts.
- Create `verification/psalm_sources/psalm_text_editions.csv`: generated long-form edition corpus.
- Create `verification/psalm_sources/psalm_text_comparison.csv`: generated wide full-text comparison file.
- Create `verification/psalm_sources/psalm_usage_map.csv`: generated liturgical usage mapping.
- Create `assets/data/psalm_editions/manifest.json`: runtime edition-pack manifest.
- Create `assets/data/psalm_editions/*.csv`: bundled runtime packs for renderable editions.

### Runtime models and services

- Create `lib/data/models/responsorial_psalm_edition.dart`: edition metadata and availability state.
- Create `lib/data/models/resolved_responsorial_psalm.dart`: rendered text plus requested/actual edition and fallback provenance.
- Create `lib/data/services/responsorial_psalm_edition_registry.dart`: load and query the pack manifest.
- Create `lib/data/services/responsorial_psalm_preference.dart`: persist the psalm-only edition choice.
- Create `lib/data/services/responsorial_psalm_source_pack_service.dart`: load, validate, cache, and query edition packs.
- Create `lib/data/services/responsorial_psalm_fallback_service.dart`: execute the approved fallback chain.
- Modify `lib/data/services/responsorial_psalm_text_catalog_service.dart`: delegate pack parsing and matching to the new pack service.
- Modify `lib/data/services/readings_service.dart`: expose structured psalm resolution while retaining the string API.
- Modify `lib/data/services/reading_flow_service.dart`: hydrate psalm provenance alongside text.
- Modify `lib/data/models/reading_session.dart`: retain resolved psalm provenance per reading.

### UI

- Create `lib/ui/widgets/responsorial_psalm_edition_selector.dart`: psalm-only edition picker.
- Create `lib/ui/widgets/responsorial_psalm_source_label.dart`: actual-edition and fallback label.
- Modify `lib/ui/screens/settings_screen.dart`: add the independent responsorial psalm selector.
- Modify `lib/ui/screens/reading_screen.dart`: reload on psalm-edition changes and display provenance.
- Modify `pubspec.yaml`: bundle the psalm edition manifest and packs; bump the release version after all gates pass.

### Tests

- Create `test/data/services/responsorial_psalm_edition_registry_test.dart`.
- Create `test/data/services/responsorial_psalm_preference_test.dart`.
- Create `test/data/services/responsorial_psalm_source_pack_service_test.dart`.
- Create `test/data/services/responsorial_psalm_fallback_service_test.dart`.
- Modify `test/data/services/responsorial_psalm_runtime_integrity_test.dart`.
- Modify `test/data/services/reading_choices_exhaustive_test.dart`.
- Create `test/ui/screens/settings_psalm_edition_test.dart`.
- Modify `test/ui/screens/premium_browse_reading_choices_test.dart`.

---

### Task 1: Lock the Multi-Edition Corpus Contract

**Files:**
- Modify: `test/scripts/responsorial_psalm_corpus_test.py`
- Modify: `scripts/psalm_sources/models.py`
- Modify: `scripts/psalm_sources/source_registry.json`

- [ ] **Step 1: Add failing model and registry tests**

Add tests that require each registry record to expose `source_kind`, `pack_id`, `renderability`, `fallback_role`, and `coverage_status`, and require a canonical edition row to retain complete text and hashes:

```python
def test_registry_describes_runtime_psalm_editions(self):
    registry = load_registry()
    by_id = {row["source_id"]: row for row in registry}
    for source_id in {
        "nigeria_365_firestore",
        "modern_psalter_us",
        "local_rsvce",
        "local_nabre",
        "douay_rheims",
        "jerusalem_bible",
        "esvce",
    }:
        row = by_id[source_id]
        self.assertIn(row["source_kind"], {"lectionary", "bible", "psalter"})
        self.assertTrue(row["pack_id"])
        self.assertIn(row["renderability"], {"bundled", "downloaded", "external"})
        self.assertIn(row["coverage_status"], {"complete", "partial", "unavailable"})


def test_edition_text_row_preserves_complete_text_and_hashes(self):
    row = PsalmEditionText(
        selection_id="ps45_10_11_12_16",
        edition_id="local_rsvce",
        reference_normalized="ps45:10,11,12,16",
        response_text="The queen stands at your right hand, arrayed in gold.",
        stanzas=("A first complete stanza.", "A second complete stanza."),
        source_url="repo://assets/rsvce.db",
    )
    self.assertEqual(row.stanzas_text, "A first complete stanza.\n\nA second complete stanza.")
    self.assertEqual(len(row.raw_sha256), 64)
    self.assertEqual(len(row.normalized_sha256), 64)
```

- [ ] **Step 2: Run the focused Python test and confirm RED**

Run:

```powershell
python test/scripts/responsorial_psalm_corpus_test.py
```

Expected: FAIL because `PsalmEditionText` and the new registry fields do not exist.

- [ ] **Step 3: Add the canonical models**

Add these focused types to `scripts/psalm_sources/models.py`:

```python
@dataclass(frozen=True)
class PsalmEditionText:
    selection_id: str
    edition_id: str
    reference_normalized: str
    response_text: str
    stanzas: tuple[str, ...]
    source_url: str
    source_edition: str = ""
    territory: str = "WORLD"
    coverage_status: str = "complete"
    missing_reason: str = ""

    @property
    def stanzas_text(self) -> str:
        return "\n\n".join(value.strip() for value in self.stanzas if value.strip())

    @property
    def raw_sha256(self) -> str:
        value = f"{self.response_text.strip()}\n\n{self.stanzas_text}"
        return hashlib.sha256(value.encode("utf-8")).hexdigest()

    @property
    def normalized_sha256(self) -> str:
        value = normalize_words(f"{self.response_text} {self.stanzas_text}")
        return hashlib.sha256(value.encode("utf-8")).hexdigest()


@dataclass(frozen=True)
class PsalmUsage:
    usage_id: str
    selection_id: str
    territory: str
    date_rule: str
    celebration_id: str
    celebration_title: str
    reading_set_kind: str
    reading_set_priority: int
    sunday_cycle: str = ""
    weekday_cycle: str = ""
    lectionary_number: str = ""
```

Update the seven registry rows with the fields asserted by the test. Mark only sources with an actual bundled or downloaded pack as renderable; do not infer renderability from metadata.

- [ ] **Step 4: Run the focused test and confirm GREEN**

Run `python test/scripts/responsorial_psalm_corpus_test.py`.

Expected: all existing and new contract tests pass.

- [ ] **Step 5: Commit**

```powershell
git add test/scripts/responsorial_psalm_corpus_test.py scripts/psalm_sources/models.py scripts/psalm_sources/source_registry.json
git commit -m "test: define responsorial psalm edition corpus"
```

---

### Task 2: Extract Complete Bible-Edition Selections

**Files:**
- Create: `scripts/psalm_sources/bible_databases.py`
- Modify: `test/scripts/responsorial_psalm_corpus_test.py`

- [ ] **Step 1: Add failing extraction tests**

Use a temporary SQLite fixture constructed in the test so the binary fixture can be regenerated deterministically:

```python
def test_bible_database_extracts_requested_verses_in_selection_order(self):
    path = build_bible_fixture(
        books=[(1, "Psalms", "Ps")],
        verses=[
            (1, 45, 10, "Daughters of kings are among your ladies of honor."),
            (1, 45, 11, "Hear, O daughter, and consider."),
            (1, 45, 12, "The king will desire your beauty."),
            (1, 45, 16, "With joy and gladness they are led along."),
        ],
    )
    result = extract_bible_selection(
        path,
        edition_id="fixture",
        reference="Ps 45:10, 11, 12, 16",
    )
    self.assertEqual(result.reference_normalized, "ps45:10,11,12,16")
    self.assertEqual(len(result.stanzas), 4)
    self.assertIn("Hear, O daughter", result.stanzas_text)
```

Add a canticle case for `Isa 12:2-3,4,5-6` and a verse-letter case such as `Ps 34:2-3,4-5,6-7,8-9`.

- [ ] **Step 2: Run the new tests and confirm RED**

Run `python test/scripts/responsorial_psalm_corpus_test.py`.

Expected: FAIL because `extract_bible_selection` is missing.

- [ ] **Step 3: Implement the SQLite extractor**

Create `scripts/psalm_sources/bible_databases.py` with a parser that expands normalized selection groups, preserves group boundaries as stanzas, resolves book aliases through the `books.shortname` column, and returns `PsalmEditionText`:

```python
def extract_bible_selection(
    database: Path,
    *,
    edition_id: str,
    reference: str,
    response_text: str = "",
    source_url: str = "",
) -> PsalmEditionText:
    parsed = parse_selection(reference)
    with sqlite3.connect(database) as connection:
        book_id = resolve_book_id(connection, parsed.book)
        stanzas = tuple(
            " ".join(
                lookup_verse(connection, book_id, group.chapter, verse)
                for verse in group.verses
            )
            for group in parsed.groups
        )
    return PsalmEditionText(
        selection_id=selection_id_for(parsed.normalized),
        edition_id=edition_id,
        reference_normalized=parsed.normalized,
        response_text=response_text,
        stanzas=stanzas,
        source_url=source_url or f"repo://{database.as_posix()}",
    )
```

Treat verse letters as selection metadata while retrieving the complete numbered verse. Record this normalization in the audit rather than truncating a verse heuristically.

- [ ] **Step 4: Verify RSVCE and NABRE smoke selections**

Add tests against `assets/rsvce.db` and `assets/nabre.db` for Psalm 45 and Isaiah 12. Assert non-empty complete text, stable hashes, and distinct normalized hashes between the two editions.

Run `python test/scripts/responsorial_psalm_corpus_test.py`.

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add scripts/psalm_sources/bible_databases.py test/scripts/responsorial_psalm_corpus_test.py
git commit -m "feat: extract full psalm text from Bible editions"
```

---

### Task 3: Generate Long, Wide, and Usage CSVs

**Files:**
- Create: `scripts/psalm_sources/edition_corpus.py`
- Modify: `scripts/build_responsorial_psalm_corpus.py`
- Modify: `test/scripts/responsorial_psalm_corpus_test.py`
- Create: `verification/psalm_sources/psalm_text_editions.csv`
- Create: `verification/psalm_sources/psalm_text_comparison.csv`
- Create: `verification/psalm_sources/psalm_usage_map.csv`

- [ ] **Step 1: Add failing wide-comparison tests**

```python
def test_wide_comparison_contains_full_text_from_two_editions(self):
    comparison = build_wide_comparison(
        usages=[fixture_usage("ps45_10_11_12_16")],
        edition_rows=[fixture_rsvce_row(), fixture_nabre_row()],
        baseline_edition="local_rsvce",
    )
    row = comparison[0]
    self.assertEqual(row["selection_id"], "ps45_10_11_12_16")
    self.assertTrue(row["local_rsvce_stanzas_text"])
    self.assertTrue(row["local_nabre_stanzas_text"])
    self.assertEqual(row["complete_edition_count"], 2)
    self.assertEqual(row["comparison_status"], "comparison_ready")
    self.assertIn(row["local_nabre_difference_class"], {
        "exact", "punctuation_only", "translation_variant"
    })
```

Add CSV round-trip coverage proving quoted multiline stanza cells deserialize byte-for-byte.

- [ ] **Step 2: Run tests and confirm RED**

Run `python test/scripts/responsorial_psalm_corpus_test.py`.

Expected: FAIL because the edition-corpus builder and three-output contract are absent.

- [ ] **Step 3: Implement corpus reconciliation**

Create `edition_corpus.py` with:

```python
TARGET_EDITIONS = (
    "nigeria_365_firestore",
    "modern_psalter_us",
    "jerusalem_bible",
    "esvce",
    "local_rsvce",
    "local_nabre",
    "douay_rheims",
)


def build_wide_comparison(usages, edition_rows, *, baseline_edition):
    by_selection = index_editions(edition_rows)
    output = []
    for selection_id in sorted({usage.selection_id for usage in usages}):
        row = {"selection_id": selection_id}
        complete = 0
        baseline = by_selection.get((selection_id, baseline_edition))
        for edition_id in TARGET_EDITIONS:
            text = by_selection.get((selection_id, edition_id))
            add_edition_columns(row, edition_id, text)
            if text is not None and text.stanzas_text.strip():
                complete += 1
            add_baseline_metrics(row, edition_id, baseline, text)
        row["complete_edition_count"] = complete
        row["comparison_status"] = (
            "comparison_ready" if complete >= 2 else "insufficient_editions"
        )
        output.append(row)
    return output
```

Use Python's `csv.DictWriter` with `newline=""`, UTF-8, and deterministic header order. Preserve true newlines inside quoted full-text cells; do not replace them with lossy delimiters.

- [ ] **Step 4: Extend the top-level generator**

Update `build_responsorial_psalm_corpus.py` to:

1. Load normalized liturgical usages.
2. Extract Nigeria and Modern Psalter full-text rows.
3. Generate RSVCE and NABRE rows from bundled SQLite assets.
4. Generate Douay-Rheims rows when its local database path is supplied.
5. Import installed Jerusalem or ESV-CE source packs when present.
6. Write the long corpus, wide comparison, usage map, runtime packs, and audit JSON atomically.

Add arguments:

```python
parser.add_argument("--douay-db", type=Path)
parser.add_argument("--external-pack-dir", type=Path)
parser.add_argument("--full-text-output", type=Path, required=True)
```

The generated report must include `comparison_ready_count`, `insufficient_edition_count`, and per-edition complete-selection counts.

- [ ] **Step 5: Generate deterministic fixtures and confirm GREEN**

Run:

```powershell
python test/scripts/responsorial_psalm_corpus_test.py
python scripts/build_responsorial_psalm_corpus.py --fixture-mode --full-text-output verification/psalm_sources
```

Expected: tests pass; all three CSV files are generated; the fixture report has at least one comparison-ready row with RSVCE and NABRE full text.

- [ ] **Step 6: Commit**

```powershell
git add scripts/psalm_sources/edition_corpus.py scripts/build_responsorial_psalm_corpus.py test/scripts/responsorial_psalm_corpus_test.py verification/psalm_sources/psalm_text_editions.csv verification/psalm_sources/psalm_text_comparison.csv verification/psalm_sources/psalm_usage_map.csv verification/psalm_sources/responsorial_psalm_audit_report.json
git commit -m "feat: generate full-text psalm edition comparison"
```

---

### Task 4: Build and Validate Runtime Source Packs

**Files:**
- Create: `scripts/psalm_sources/source_packs.py`
- Modify: `scripts/psalm_sources/nigeria_365.py`
- Modify: `scripts/psalm_sources/modern_psalter.py`
- Modify: `scripts/build_responsorial_psalm_corpus.py`
- Create: `assets/data/psalm_editions/manifest.json`
- Create: `assets/data/psalm_editions/nigeria_365.csv`
- Create: `assets/data/psalm_editions/modern_psalter_us.csv`
- Create: `assets/data/psalm_editions/rsvce.csv`
- Create: `assets/data/psalm_editions/nabre.csv`
- Modify: `test/scripts/responsorial_psalm_corpus_test.py`

- [ ] **Step 1: Add failing pack validation tests**

```python
def test_runtime_pack_rejects_conflicting_duplicate_selection(self):
    rows = [fixture_pack_row(text="First"), fixture_pack_row(text="Different")]
    with self.assertRaisesRegex(ValueError, "conflicting duplicate"):
        validate_source_pack(rows)


def test_manifest_only_marks_nonempty_validated_packs_installed(self):
    manifest = build_manifest(
        registry=load_registry(),
        packs={"local_rsvce": [fixture_pack_row()]},
    )
    self.assertTrue(manifest["local_rsvce"]["installed"])
    self.assertFalse(manifest["jerusalem_bible"]["installed"])
```

- [ ] **Step 2: Run tests and confirm RED**

Run `python test/scripts/responsorial_psalm_corpus_test.py`.

Expected: FAIL because source-pack validation and manifest generation do not exist.

- [ ] **Step 3: Implement pack validation and serialization**

Create `source_packs.py` with a fixed 17-column schema including edition, selection, qualifiers, response, complete stanzas, provenance, hashes, and priority. Reject empty stanza text, invalid hashes, and unresolved duplicate keys.

```python
PACK_KEY = (
    "edition_id", "selection_id", "territory", "celebration_id",
    "reading_set_kind", "sunday_cycle", "weekday_cycle",
)


def validate_source_pack(rows):
    seen = {}
    for row in rows:
        if not row.stanzas_text.strip():
            raise ValueError(f"missing stanza text: {row.selection_id}")
        key = tuple(getattr(row, field) for field in PACK_KEY)
        previous = seen.get(key)
        if previous is not None and previous.raw_sha256 != row.raw_sha256:
            raise ValueError(f"conflicting duplicate: {key}")
        seen[key] = row
    return tuple(seen[key] for key in sorted(seen))
```

- [ ] **Step 4: Populate edition packs**

Convert available Nigeria and Modern Psalter source rows directly from their full parsed stanza blocks. Generate RSVCE and NABRE packs from the SQLite extractor for every normalized usage selection. Include a source in the installed manifest only when its pack validates and contains at least one complete row.

External Jerusalem, ESV-CE, and Douay-Rheims packs use the same schema and validator. Their registry entries remain visible as downloadable/external metadata, but the selector must not claim they are installed until a validated pack exists.

- [ ] **Step 5: Verify generated packs**

Run:

```powershell
python test/scripts/responsorial_psalm_corpus_test.py
python scripts/build_responsorial_psalm_corpus.py --fixture-mode --full-text-output verification/psalm_sources --runtime-output assets/data/psalm_editions
```

Expected: every installed manifest edition has a nonempty pack; every pack row has complete text and valid hashes.

- [ ] **Step 6: Commit**

```powershell
git add scripts/psalm_sources/source_packs.py scripts/psalm_sources/nigeria_365.py scripts/psalm_sources/modern_psalter.py scripts/build_responsorial_psalm_corpus.py assets/data/psalm_editions test/scripts/responsorial_psalm_corpus_test.py
git commit -m "data: build responsorial psalm edition packs"
```

---

### Task 5: Add Edition Registry and Preference

**Files:**
- Create: `lib/data/models/responsorial_psalm_edition.dart`
- Create: `lib/data/services/responsorial_psalm_edition_registry.dart`
- Create: `lib/data/services/responsorial_psalm_preference.dart`
- Create: `test/data/services/responsorial_psalm_edition_registry_test.dart`
- Create: `test/data/services/responsorial_psalm_preference_test.dart`
- Modify: `pubspec.yaml`

- [ ] **Step 1: Write failing Dart tests**

```dart
test('registry separates installed and unavailable psalm editions', () async {
  final registry = ResponsorialPsalmEditionRegistry.fromJson(fixtureManifest);
  expect(registry.requireById('local_rsvce').isInstalled, isTrue);
  expect(registry.requireById('esvce').isInstalled, isFalse);
  expect(registry.selectable.map((e) => e.id), contains('local_rsvce'));
  expect(registry.selectable.map((e) => e.id), isNot(contains('esvce')));
});

test('preference is independent from BibleVersionPreference', () async {
  SharedPreferences.setMockInitialValues({});
  final psalm = await ResponsorialPsalmPreference.getInstance();
  final bible = await BibleVersionPreference.getInstance();
  await psalm.setEditionId('nigeria_365_firestore');
  expect(psalm.currentEditionId, 'nigeria_365_firestore');
  expect(bible.currentVersion, BibleVersionType.rsvce);
});
```

- [ ] **Step 2: Run tests and confirm RED**

Run:

```powershell
flutter test --no-pub test/data/services/responsorial_psalm_edition_registry_test.dart test/data/services/responsorial_psalm_preference_test.dart
```

Expected: compilation fails because the model and services are missing.

- [ ] **Step 3: Implement registry and preference**

Define:

```dart
enum ResponsorialPsalmSourceKind { lectionary, bible, psalter }

class ResponsorialPsalmEdition {
  final String id;
  final String displayName;
  final String abbreviation;
  final ResponsorialPsalmSourceKind sourceKind;
  final List<String> territories;
  final String coverageStatus;
  final String packAsset;
  final bool isInstalled;
  final bool isDownloadable;
  final String sourceUrl;

  const ResponsorialPsalmEdition({
    required this.id,
    required this.displayName,
    required this.abbreviation,
    required this.sourceKind,
    required this.territories,
    required this.coverageStatus,
    required this.packAsset,
    required this.isInstalled,
    required this.isDownloadable,
    required this.sourceUrl,
  });
}
```

Persist the psalm preference under `preferred_responsorial_psalm_edition`. Default to `territory_lectionary`, a virtual preference that begins the chain at the region-specific source.

- [ ] **Step 4: Bundle the manifest and run tests**

Add `assets/data/psalm_editions/` to `pubspec.yaml` and run the two tests.

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add lib/data/models/responsorial_psalm_edition.dart lib/data/services/responsorial_psalm_edition_registry.dart lib/data/services/responsorial_psalm_preference.dart test/data/services/responsorial_psalm_edition_registry_test.dart test/data/services/responsorial_psalm_preference_test.dart pubspec.yaml
git commit -m "feat: add responsorial psalm edition preferences"
```

---

### Task 6: Resolve Source Packs with Deterministic Fallback

**Files:**
- Create: `lib/data/models/resolved_responsorial_psalm.dart`
- Create: `lib/data/services/responsorial_psalm_source_pack_service.dart`
- Create: `lib/data/services/responsorial_psalm_fallback_service.dart`
- Modify: `lib/data/services/responsorial_psalm_text_catalog_service.dart`
- Create: `test/data/services/responsorial_psalm_source_pack_service_test.dart`
- Create: `test/data/services/responsorial_psalm_fallback_service_test.dart`

- [ ] **Step 1: Add failing pack and fallback tests**

```dart
test('fallback order is selected, territory, Bible, RSVCE', () async {
  final resolver = fixtureResolver(
    packs: {
      'nigeria_365_firestore': [nigeriaPsalm45],
      'local_nabre': [nabrePsalm45],
      'local_rsvce': [rsvcePsalm45],
    },
  );
  final selected = await resolver.resolve(
    request: fixtureRequest(selectedEditionId: 'modern_psalter_us'),
    territoryEditionId: 'nigeria_365_firestore',
    bibleEditionId: 'local_nabre',
  );
  expect(selected.actualEditionId, 'nigeria_365_firestore');
  expect(selected.didFallback, isTrue);
  expect(selected.fallbackReason, PsalmFallbackReason.selectedEditionMissing);
});

test('fallback never changes the authoritative selection', () async {
  final result = await fixtureResolver().resolve(
    request: assumptionDayRequest,
    territoryEditionId: 'nigeria_365_firestore',
    bibleEditionId: 'local_nabre',
  );
  expect(result.referenceNormalized, 'ps45:10,11,12,16');
  expect(result.text, isNot(contains('ps132')));
});
```

- [ ] **Step 2: Run tests and confirm RED**

Run the two new service test files.

Expected: compilation fails because the pack and fallback services are missing.

- [ ] **Step 3: Implement structured resolution**

Create:

```dart
enum PsalmFallbackReason {
  none,
  selectedEditionMissing,
  selectedPackUnavailable,
  territoryEditionMissing,
  bibleEditionMissing,
  corruptPack,
}

class ResolvedResponsorialPsalm {
  final String text;
  final String responseText;
  final String requestedEditionId;
  final String actualEditionId;
  final String actualEditionName;
  final String referenceNormalized;
  final PsalmFallbackReason fallbackReason;
  final String sourceUrl;

  const ResolvedResponsorialPsalm({required this.text, required this.responseText,
    required this.requestedEditionId, required this.actualEditionId,
    required this.actualEditionName, required this.referenceNormalized,
    required this.fallbackReason, required this.sourceUrl});

  bool get didFallback => fallbackReason != PsalmFallbackReason.none;
}
```

The fallback service builds a de-duplicated candidate list in the approved order and returns the first exact selection match. It must pass the original reference, celebration, reading-set kind, cycle, date, and territory to every pack lookup.

- [ ] **Step 4: Preserve lectionary responses**

When a Bible-derived pack supplies stanza text, keep the reviewed response passed in the request. Only a reviewed lectionary or psalter pack may replace it with its edition-specific response.

- [ ] **Step 5: Run tests and confirm GREEN**

Run:

```powershell
flutter test --no-pub test/data/services/responsorial_psalm_source_pack_service_test.dart test/data/services/responsorial_psalm_fallback_service_test.dart test/lectionary_psalm_catalog_service_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add lib/data/models/resolved_responsorial_psalm.dart lib/data/services/responsorial_psalm_source_pack_service.dart lib/data/services/responsorial_psalm_fallback_service.dart lib/data/services/responsorial_psalm_text_catalog_service.dart test/data/services/responsorial_psalm_source_pack_service_test.dart test/data/services/responsorial_psalm_fallback_service_test.dart
git commit -m "feat: resolve responsorial psalm edition fallback"
```

---

### Task 7: Integrate Resolution and Provenance into Reading Flow

**Files:**
- Modify: `lib/data/services/readings_service.dart`
- Modify: `lib/data/services/reading_flow_service.dart`
- Modify: `lib/data/models/reading_session.dart`
- Modify: `test/data/services/responsorial_psalm_runtime_integrity_test.dart`
- Modify: `test/data/models/reading_session_context_test.dart`

- [ ] **Step 1: Add failing integration tests**

```dart
test('selected psalm edition changes only responsorial stanza text', () async {
  SharedPreferences.setMockInitialValues({});
  final biblePreference = await BibleVersionPreference.getInstance();
  final psalmPreference = await ResponsorialPsalmPreference.getInstance();
  await biblePreference.setVersion(BibleVersionType.rsvce);
  await psalmPreference.setEditionId('nigeria_365_firestore');
  final first = await flow.hydrateReadingSet(date: assumption, readings: readings);
  await psalmPreference.setEditionId('local_nabre');
  final second = await flow.hydrateReadingSet(date: assumption, readings: readings);
  expect(first.readingTexts[firstReadingRef], second.readingTexts[firstReadingRef]);
  expect(first.readingTexts[psalmRef], isNot(second.readingTexts[psalmRef]));
  expect(second.psalmSources[psalmRef]!.actualEditionId, 'local_nabre');
});
```

Add session copy/select tests proving `psalmSources` is retained.

- [ ] **Step 2: Run tests and confirm RED**

Run the two modified test files.

Expected: FAIL because structured psalm resolution is not exposed through the reading flow.

- [ ] **Step 3: Add the structured service API**

Add `ReadingsService.resolveResponsorialPsalm(...)` returning `ResolvedResponsorialPsalm`. Keep `getReadingText(...)` backward-compatible by returning `.text` for responsorial psalms.

Extend `HydratedReadingSet` and `ReadingSession` with:

```dart
final Map<String, ResolvedResponsorialPsalm> psalmSources;
```

Populate this map only for responsorial psalms. Non-psalm paths continue to use `BibleVersionPreference` unchanged.

- [ ] **Step 4: Run integration tests and confirm GREEN**

Run:

```powershell
flutter test --no-pub test/data/services/responsorial_psalm_runtime_integrity_test.dart test/data/models/reading_session_context_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add lib/data/services/readings_service.dart lib/data/services/reading_flow_service.dart lib/data/models/reading_session.dart test/data/services/responsorial_psalm_runtime_integrity_test.dart test/data/models/reading_session_context_test.dart
git commit -m "feat: carry psalm edition provenance through readings"
```

---

### Task 8: Add the Psalm Edition Selector and Fallback Label

**Files:**
- Create: `lib/ui/widgets/responsorial_psalm_edition_selector.dart`
- Create: `lib/ui/widgets/responsorial_psalm_source_label.dart`
- Modify: `lib/ui/screens/settings_screen.dart`
- Modify: `lib/ui/screens/reading_screen.dart`
- Create: `test/ui/screens/settings_psalm_edition_test.dart`
- Modify: `test/ui/screens/premium_browse_reading_choices_test.dart`

- [ ] **Step 1: Add failing widget tests**

```dart
testWidgets('settings selects psalm edition independently of Bible', (tester) async {
  await pumpSettings(tester, installedPsalmEditions: fixtureEditions);
  await tester.tap(find.text('Responsorial Psalm text'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Catholic Missal Nigeria'));
  await tester.pumpAndSettle();
  expect(await psalmPreference.currentEditionId, 'nigeria_365_firestore');
  expect(biblePreference.currentVersion, BibleVersionType.rsvce);
});

testWidgets('reading labels the actual fallback edition', (tester) async {
  await pumpPsalmReading(tester, resolution: fixtureFallbackResolution);
  expect(find.text('NABRE fallback — selected edition unavailable for this psalm'),
      findsOneWidget);
});
```

- [ ] **Step 2: Run tests and confirm RED**

Run the new settings test and modified reading choices UI test.

Expected: FAIL because the selector and source label do not exist.

- [ ] **Step 3: Implement the settings selector**

Add a `Responsorial Psalm text` tile under the Readings section. The dialog lists all registry editions but enables only installed editions; downloadable and unavailable editions show their status without being falsely selectable.

The selector listens to `ResponsorialPsalmPreference` and calls a psalm-only refresh callback. It does not call `BibleVersionPreference.setVersion`.

- [ ] **Step 4: Implement reading provenance**

For responsorial psalms, replace the generic Bible footer with `ResponsorialPsalmSourceLabel`. Display the actual edition name. If `didFallback` is true, append a human-readable reason. Keep the ordinary `BibleVersionSwitcher` for all non-psalm readings.

On psalm-edition changes, reload only the current responsorial psalm using the same date, territory, celebration ID, reading-set kind, and lectionary number.

- [ ] **Step 5: Run widget tests and confirm GREEN**

Run:

```powershell
flutter test --no-pub test/ui/screens/settings_psalm_edition_test.dart test/ui/screens/premium_browse_reading_choices_test.dart test/ui/screens/settings_bible_preference_test.dart
```

Expected: PASS; existing Bible selector behavior remains unchanged.

- [ ] **Step 6: Commit**

```powershell
git add lib/ui/widgets/responsorial_psalm_edition_selector.dart lib/ui/widgets/responsorial_psalm_source_label.dart lib/ui/screens/settings_screen.dart lib/ui/screens/reading_screen.dart test/ui/screens/settings_psalm_edition_test.dart test/ui/screens/premium_browse_reading_choices_test.dart
git commit -m "feat: select responsorial psalm text editions"
```

---

### Task 9: Exhaustively Verify Selection, Coverage, and Comparison Data

**Files:**
- Modify: `test/data/services/reading_choices_exhaustive_test.dart`
- Modify: `test/data/services/responsorial_psalm_runtime_integrity_test.dart`
- Modify: `test/scripts/responsorial_psalm_corpus_test.py`
- Modify: `verification/psalm_sources/responsorial_psalm_audit_report.json`

- [ ] **Step 1: Add exhaustive edition assertions**

For every fixed feast, memorial, movable solemnity, Sunday cycle, weekday cycle, and alternative in the existing exhaustive matrix, assert:

```dart
expect(resolution.referenceNormalized, normalizeReference(reading.reading));
expect(resolution.text.trim(), isNotEmpty);
expect(resolution.actualEditionId.trim(), isNotEmpty);
expect(validFallbackOrder(resolution), isTrue);
```

For Assumption, assert Psalm 45 remains the Day selection and Psalm 132 remains the Vigil selection across every installed edition and fallback path.

- [ ] **Step 2: Add corpus completeness assertions**

Require:

```python
self.assertEqual(report["conflicting_pack_row_count"], 0)
self.assertEqual(report["invalid_hash_count"], 0)
self.assertEqual(report["orphan_usage_count"], 0)
self.assertEqual(report["comparison_ready_count"], report["unique_selection_count"])
self.assertEqual(report["insufficient_edition_count"], 0)
self.assertEqual(
    report["comparison_ready_count"] + report["insufficient_edition_count"],
    report["unique_selection_count"],
)
```

The report must list every insufficient selection and the exact missing editions.

- [ ] **Step 3: Run focused and exhaustive gates**

Run:

```powershell
python test/scripts/responsorial_psalm_corpus_test.py
flutter test --no-pub --concurrency=1 test/lectionary_psalm_catalog_service_test.dart test/data/services/responsorial_psalm_edition_registry_test.dart test/data/services/responsorial_psalm_preference_test.dart test/data/services/responsorial_psalm_source_pack_service_test.dart test/data/services/responsorial_psalm_fallback_service_test.dart test/data/services/responsorial_psalm_runtime_integrity_test.dart test/data/services/reading_choices_resolver_test.dart test/data/services/reading_choices_exhaustive_test.dart test/ui/screens/settings_psalm_edition_test.dart test/ui/screens/premium_browse_reading_choices_test.dart
```

Expected: all tests pass with zero selection substitutions and zero unlabeled fallbacks.

- [ ] **Step 4: Inspect the CSV with the bundled spreadsheet runtime**

Immediately before artifact inspection, mark one edit operation:

```powershell
& 'C:\Users\Son\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe' 'C:\Users\Son\.cache\codex-runtimes\codex-primary-runtime\plugins\openai-primary-runtime\plugins\spreadsheets\skills\spreadsheets\container_tools\mark_artifact_operation_started.mjs' --operation-kind edit --expected-output-count 1 --output-format csv
```

Create a temporary junction to the loader-provided Node modules, import `psalm_text_comparison.csv` using `Workbook.fromCSV`, inspect the first representative rows and edition columns, scan for formula-error tokens, and render a bounded review range. Verify that headers are visible, multiline stanza cells survive import, and representative hashes/text match the Python reader. Do not commit the temporary workbook, preview, junction, or script.

- [ ] **Step 5: Run static and full-suite gates**

Run:

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --no-pub --concurrency=1
git diff --check
```

Expected: format clean; analyze reports no issues; full suite has zero failures; diff check is clean.

- [ ] **Step 6: Commit**

```powershell
git add test/data/services/reading_choices_exhaustive_test.dart test/data/services/responsorial_psalm_runtime_integrity_test.dart test/scripts/responsorial_psalm_corpus_test.py verification/psalm_sources/responsorial_psalm_audit_report.json
git commit -m "test: audit responsorial psalm editions exhaustively"
```

---

### Task 10: Release Audit and Version Bump

**Files:**
- Modify: `pubspec.yaml`
- Modify: `test/QA_REGRESSION_CHECKLIST.md`

- [ ] **Step 1: Document manual acceptance cases**

Add these cases to `test/QA_REGRESSION_CHECKLIST.md`:

- Assumption Day uses Psalm 45 first and exposes Vigil Psalm 132.
- Changing responsorial psalm edition changes only the psalm stanza text.
- Selected edition is labeled when used.
- Fallback edition and reason are labeled when selected coverage is absent.
- Nigeria territory prefers Catholic Missal Nigeria in territory fallback.
- Missing/corrupt packs never substitute another psalm selection.

- [ ] **Step 2: Bump the app version**

Change `pubspec.yaml` from `1.6.7+32` to `1.6.8+33` after confirming that no intervening commit has already changed the version.

- [ ] **Step 3: Re-run release gates on the exact versioned tree**

Run:

```powershell
flutter pub get
flutter analyze
flutter test --no-pub --concurrency=1
python test/scripts/responsorial_psalm_corpus_test.py
git diff --check
git status --short
```

Restore only known generated platform registrant changes if `flutter pub get` rewrites them without a dependency change. Do not alter unrelated user files.

- [ ] **Step 4: Commit the release audit**

```powershell
git add pubspec.yaml test/QA_REGRESSION_CHECKLIST.md
git commit -m "release: add responsorial psalm edition packs"
```

- [ ] **Step 5: Inspect the committed range**

Run:

```powershell
git status --short
git log --oneline --decorate -12
git diff --check origin/main..HEAD
git diff --stat origin/main..HEAD
```

Expected: tracked worktree clean; only intended corpus/runtime/UI/test/version files changed; no APKs, credentials, temporary workbooks, or extracted source caches are committed.
