# Complete Saint Corpus Research and Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Manually research, source, write, review, and publish structured v2 life guides for all 158 existing saint and Marian celebration profiles.

**Architecture:** Each profile is an independently reviewable JSON asset plus a committed Markdown research dossier. A deterministic queue tool measures migration by stable ID and editorial state. Profiles move through fixed source, claim-ledger, writing, factual-review, theological-review, validation, and publication gates in a representative pilot followed by twelve calendar-ordered batches and a two-profile variable-date batch.

**Tech Stack:** Bundled JSON, Dart command-line tooling, Flutter model/validator from the foundation plan, Markdown research dossiers, primary Catholic sources, scholarly references, Wikidata/Wikipedia discovery metadata.

---

**Dependency:** Complete `2026-08-10-saint-life-guide-foundation.md` through Task 7 before starting this plan.

## File responsibility map

- `docs/research/saints/README.md`: binding editorial protocol and dossier instructions.
- `docs/research/saints/batches.json`: immutable mapping of batch numbers to the exact 158 stable IDs listed in Tasks 2–15.
- `docs/research/saints/dossiers/<profile-id>.md`: identity resolution, source ledger, claim ledger, uncertainty decisions, copyright notes, and review record for one profile.
- `assets/data/saints/profiles/<profile-id>.json`: publishable offline user-facing profile and field-level source references.
- `assets/data/saints/index.json`: authoritative ordered list of researched profile assets.
- `tool/saint_research_queue.dart`: compare legacy IDs, v2 index entries, validator output, and editorial state; select or audit an explicit batch.
- `test/tool/saint_research_queue_test.dart`: queue, duplicate, unknown-ID, and completion tests.
- `assets/data/saints_profiles.json`: legacy input retained during migration and removed only after all 158 v2 files pass the final gate.
- `lib/data/services/saint_profile_repository.dart`: switch from overlay mode to v2-only loading at final cutover.

## Binding research rules for every batch

These rules are execution requirements, not optional guidance:

1. Read at least three credible sources when three exist. Include at least one Tier 1 official or primary source for modern canonized saints and celebrations with accessible official documentation.
2. Use Tier 1 first: Holy See documents, canonization material, bishops’ conferences, primary writings, liturgical documents, and official archives of the relevant diocese or religious community.
3. Use Tier 2 for historical control: critical editions, academic books or articles, recognized reference works, and verified public-domain Catholic references.
4. Use Wikidata and Wikipedia as Tier 3 discovery and cross-check sources, never as the sole authority for a material claim.
5. Record exact URLs, access date, source tier, publisher/institution, reuse basis, and the profile fields or claims supported.
6. Resolve conflicting claims by source proximity, date, genre, and scholarly reliability—not by majority vote. Record the rejected or unresolved version in the dossier.
7. Classify claims as `documented`, `reliablyTraditional`, `legendary`, `disputed`, or `mixed`. Do not silently convert tradition into history.
8. Verify quotation text, attribution, edition/translation, and exact source. Omit the quote object when exact verification is unavailable.
9. Write all biography, reflection, practice, and prayer prose originally. Do not paraphrase a single copyrighted biography paragraph-by-paragraph.
10. Do not copy Vatican News or publisher prose. Treat it as verification/linking material unless explicit reuse rights say otherwise.
11. Include an image only after verifying the individual file license and recording creator, source page, license, credit line, and derivative status. A text-only profile is acceptable; incomplete attribution is not.
12. Make `whyItMatters`, virtues, practices, questions, and prayer specific to documented aspects of this subject. If the name could be swapped without changing the text, rewrite it.
13. Describe martyrdom, abuse, persecution, illness, and violence accurately without graphic detail or sensational devotional language.
14. Preserve diacritics and Unicode spelling. Add aliases for search; never store mojibake.
15. A profile reaches `published` only after separate factual/content and theological passes are recorded. During agent execution, the first pass rechecks claims against sources and the second pass re-reads only the spiritual interpretation, Scripture connection, practice, questions, and prayer against the approved design references.

## Required dossier structure

Every `docs/research/saints/dossiers/<profile-id>.md` must contain all of the following headings with substantive content; do not use `TBD`, `TODO`, or empty cells:

```markdown
# <Canonical profile name>

## Identity resolution
- Stable ID:
- Profile kind:
- Celebration IDs:
- Canonical name and aliases:
- Feast date and calendar scope:
- Identity conflicts resolved:

## Source ledger
| ID | Tier | Author/institution | Title | Publisher | URL | Accessed | Reuse basis |
|---|---:|---|---|---|---|---|---|

## Claim ledger
| Profile field | Claim or editorial conclusion | Source IDs | Certainty | Reconciliation note |
|---|---|---|---|---|

## Copyright and media decision
State what was used as facts only, what may be quoted, and whether an image was accepted or deliberately omitted.

## Content review
Record checks for dates, names, locations, vocation, turning points, death/canonization, patronage, symbols, and quotation.

## Theological review
Record checks for Christ-centred framing, intercession language, Scripture connection, practical action, pastoral safety, and app-authored prayer labelling.

## Final validation
Record the exact validator command, result, reviewer, review date, and content revision.
```

If reviewed sources do not establish a requested fact, write “Not established by the reviewed sources; omitted from the profile” in the relevant dossier decision and omit the JSON field.

### Task 1: Add the research queue and dossier gate

**Files:**
- Create: `docs/research/saints/README.md`
- Create: `docs/research/saints/batches.json`
- Create: `tool/saint_research_queue.dart`
- Create: `test/tool/saint_research_queue_test.dart`

- [ ] **Step 1: Write failing queue tests**

```dart
test('queue returns legacy ids not represented by published v2 profiles', () {
  final result = SaintResearchQueue.compute(
    legacyIds: const ['a', 'b', 'c'],
    indexedProfiles: const [
      IndexedSaintProfile(id: 'a', state: 'published'),
      IndexedSaintProfile(id: 'b', state: 'researched'),
    ],
  );

  expect(result.published, ['a']);
  expect(result.inProgress, ['b']);
  expect(result.remaining, ['c']);
  expect(result.unknownIndexedIds, isEmpty);
});

test('queue reports duplicate and unknown indexed ids', () {
  final result = SaintResearchQueue.compute(
    legacyIds: const ['a'],
    indexedProfiles: const [
      IndexedSaintProfile(id: 'x', state: 'published'),
      IndexedSaintProfile(id: 'x', state: 'published'),
    ],
  );

  expect(result.duplicateIndexedIds, ['x']);
  expect(result.unknownIndexedIds, ['x']);
  expect(result.isComplete, isFalse);
});
```

- [ ] **Step 2: Run the tests to verify failure**

Run: `dart test test/tool/saint_research_queue_test.dart`

Expected: FAIL because the queue does not exist.

- [ ] **Step 3: Implement the queue tool**

`SaintResearchQueue.compute` is pure and preserves legacy calendar order. The CLI reads the legacy JSON, v2 index, and each indexed file, then prints counts for published, in-progress, remaining, duplicates, unknown IDs, missing dossier files, and invalid profiles. Support `--ids id1,id2` and `--batch 1` through `--batch 14`. Batch membership comes from `docs/research/saints/batches.json`, whose arrays contain exactly the IDs listed in Tasks 2–15. At startup, reject a batch manifest whose flattened IDs are not 158 unique legacy IDs. Exit 1 if any requested ID is unknown, missing its JSON/dossier, not published, or fails `SaintProfileValidator`.

The success footer is exact:

```text
Research gate PASS: <published>/158 published; requested batch valid.
```

- [ ] **Step 4: Write `docs/research/saints/README.md`**

Copy the binding research rules and required dossier structure from this plan. Add exact commands:

```powershell
dart run tool/saint_research_queue.dart
dart run tool/saint_research_queue.dart --ids josephine_bakhita,hildegard_of_bingen
dart run tool/saint_research_queue.dart --batch 1
dart run tool/validate_saint_profiles.dart
```

- [ ] **Step 5: Format, test, and commit tooling**

Run: `dart format tool/saint_research_queue.dart test/tool/saint_research_queue_test.dart && dart test test/tool/saint_research_queue_test.dart`

Expected: PASS.

```powershell
git add docs/research/saints/README.md docs/research/saints/batches.json tool/saint_research_queue.dart test/tool/saint_research_queue_test.dart
git commit -m "feat: gate saint profile research batches"
```

### Task 2: Research and publish the representative pilot

**Profiles:** `josephine_bakhita`, `hildegard_of_bingen`, `maximilian_mary_kolbe`, `martin_de_porres`, `teresa_of_calcutta`, `augustine_zhao_rong`, `saints_peter_and_paul_apostles`, `michael_gabriel_raphael_archangels`, `mary_mother_of_god`, `our_lady_queen_of_nigeria`, `all_saints`, `joseph_the_worker`

**Files:**
- Create: twelve matching files under `docs/research/saints/dossiers/`
- Create: twelve matching files under `assets/data/saints/profiles/`
- Modify: `assets/data/saints/index.json`

- [ ] **Step 1: Audit the unresearched pilot before writing**

Run: `dart run tool/saint_research_queue.dart --batch 1`

Expected: non-zero exit listing all twelve as missing or unpublished.

- [ ] **Step 2: Research each pilot subject manually**

For every listed ID, read and reconcile sources using the binding rules. The pilot must demonstrate all seven profile kinds or document why a narrower kind is correct. Give special attention to: enslavement and trauma language for Bakhita; authenticated writings/translations for Hildegard and Kolbe; colonial context for Martin de Porres; copyrighted modern biographies for Teresa of Calcutta; group identity for Zhao Rong and companions; Scripture/early tradition boundaries for Peter and Paul and the archangels; doctrinal versus biographical structure for Mary, Mother of God; national liturgical context for Queen of Nigeria; collective theology for All Saints; and the distinction between Saint Joseph’s biblical life and the modern Worker observance.

- [ ] **Step 3: Create complete dossiers and v2 JSON profiles**

Use the required dossier headings. Populate every JSON section required by the subject’s profile kind. Do not include an unverified quote or incompletely licensed image. Set editorial state to `contentReviewed`, run factual review, then `theologicallyReviewed`, run the spiritual review, and only then set `published`, revision `1`, with the final date and reviewer fields.

- [ ] **Step 4: Add pilot files to the index in legacy calendar order**

Every path is `assets/data/saints/profiles/<profile-id>.json`. Do not reorder existing entries from another batch and do not add a path until the matching file and dossier exist.

- [ ] **Step 5: Run the pilot gate and focused UI tests**

Run `dart run tool/saint_research_queue.dart --batch 1` again, followed by:

```powershell
dart run tool/validate_saint_profiles.dart --published-only
flutter test test/data/services/saint_profile_repository_test.dart test/data/services/saint_profile_validator_test.dart test/ui/screens/saint_detail_screen_test.dart
```

Expected: research gate PASS for 12/158; validator exits 0; focused tests pass.

- [ ] **Step 6: Review all twelve profiles in the emulator**

Use the app’s date navigation to open the fixed-date pilot profiles and direct test fixtures for variable/group profiles. Verify section order, long-text scrolling, text scale 2.0, dark theme, no mojibake, no fabricated non-applicable fields, and source-sheet links/credits.

- [ ] **Step 7: Commit the pilot as one reviewable editorial batch**

```powershell
git add docs/research/saints/dossiers assets/data/saints/profiles assets/data/saints/index.json
git commit -m "content: publish representative saint guide pilot"
```

## Standard execution steps for Tasks 3–15

Each batch task below invokes these exact requirements; none may be skipped:

1. Run `dart run tool/saint_research_queue.dart --batch N`, using the batch number in the task title, and confirm the gate fails before edits.
2. Manually read and reconcile at least three sources per profile when available, satisfying the Tier 1 exception and uncertainty rules.
3. Create one complete dossier and one complete v2 JSON file per ID; omit unsupported optional fields rather than writing generic filler.
4. Perform and record separate content/factual and theological review passes; publish only after both pass.
5. Add the profile paths to `assets/data/saints/index.json` in legacy calendar order.
6. Run the batch gate again and require PASS.
7. Run `dart run tool/validate_saint_profiles.dart --published-only` and `flutter test test/data/services/saint_profile_repository_test.dart test/data/services/saint_profile_validator_test.dart test/data/services/saint_profile_service_test.dart test/ui/screens/saint_detail_screen_test.dart`; require exit 0.
8. Inspect at least two profiles from the batch in the emulator, including the highest-risk profile kind or historical-certainty case.
9. Stage only that batch’s dossiers, JSON files, and index change, then commit with the task’s specified message.

### Task 3: Publish Batch 2 — January and early February

**Profiles:** `raymond_of_penyafort`, `hilary_of_poitiers`, `fabian_i_pope`, `sebastian_of_milan`, `vincent_of_saragossa`, `conversion_of_saint_paul`, `angela_merici`, `ansgar_of_hamburg`, `blaise_of_sebaste`, `jerome_emiliani`, `our_lady_of_lourdes`, `seven_holy_founders_of_servites`

- [ ] Run the nine standard execution requirements with `--batch 2` and require every gate to pass.
- [ ] Commit only Batch 2 files with the following command.

Commit: `git commit -m "content: research saints batch 2"`

### Task 4: Publish Batch 3 — February and March

**Profiles:** `peter_damian`, `chair_of_saint_peter`, `gregory_of_narek`, `casimir_of_poland`, `john_of_god`, `frances_of_rome`, `patrick_of_ireland`, `cyril_of_jerusalem`, `saint_joseph_spouse_of_blessed_virgin_mary`, `turibius_of_mogrovejo`, `francis_of_paola`, `isidore_of_seville`

- [ ] Run the nine standard execution requirements with `--batch 3` and require every gate to pass.
- [ ] Commit only Batch 3 files with the following command.

Commit: `git commit -m "content: research saints batch 3"`

### Task 5: Publish Batch 4 — April and early May

**Profiles:** `vincent_ferrer`, `martin_i_pope`, `anselm_of_canterbury`, `adalbert_of_prague`, `george_of_lydda`, `fidelis_of_sigmaringen`, `mark_evangelist`, `louis_grignion_de_montfort`, `peter_chanel`, `our_lady_mother_of_africa`, `pius_v_pope`, `philip_and_james_apostles`

- [ ] Run the nine standard execution requirements with `--batch 4` and require every gate to pass.
- [ ] Commit only Batch 4 files with the following command.

Commit: `git commit -m "content: research saints batch 4"`

### Task 6: Publish Batch 5 — May

**Profiles:** `john_of_avila`, `nereus_and_achilleus`, `pancras_of_rome`, `our_lady_of_fatima`, `matthias_apostle`, `john_i_pope`, `bernardine_of_siena`, `christopher_magallanes`, `rita_of_cascia`, `bede_the_venerable`, `gregory_vii_pope`, `mary_magdalene_de_pazzi`

- [ ] Run the nine standard execution requirements with `--batch 5` and require every gate to pass.
- [ ] Commit only Batch 5 files with the following command.

Commit: `git commit -m "content: research saints batch 5"`

### Task 7: Publish Batch 6 — late May and June

**Profiles:** `augustine_of_canterbury`, `paul_vi_pope`, `visitation_of_mary`, `marcellinus_and_peter`, `norbert_of_xanten`, `ephrem_the_syrian`, `saint_barnabas_apostle`, `romuald_of_ravenna`, `john_fisher_and_thomas_more`, `paulinus_of_nola`, `the_nativity_of_saint_john_the_baptist`, `cyril_of_alexandria`

- [ ] Run the nine standard execution requirements with `--batch 6` and require every gate to pass.
- [ ] Commit only Batch 6 files with the following command.

Commit: `git commit -m "content: research saints batch 6"`

### Task 8: Publish Batch 7 — late June and July

**Profiles:** `first_martyrs_of_rome`, `thomas_apostle`, `elizabeth_of_portugal`, `anthony_zaccaria`, `maria_goretti`, `henry_ii_emperor`, `camillus_de_lellis`, `our_lady_of_mount_carmel`, `apollinaris_of_ravenna`, `lawrence_of_brindisi`, `mary_magdalene`, `bridget_of_sweden`

- [ ] Run the nine standard execution requirements with `--batch 7` and require every gate to pass.
- [ ] Commit only Batch 7 files with the following command.

Commit: `git commit -m "content: research saints batch 7"`

### Task 9: Publish Batch 8 — late July and early August

**Profiles:** `sharbel_makhluf`, `james_apostle`, `peter_chrysologus`, `eusebius_of_vercelli`, `peter_julian_eymard`, `dedication_of_basilica_of_saint_mary_major`, `cajetan_of_thiene`, `sixtus_ii_pope`, `teresa_benedicta_of_the_cross`, `lawrence_of_rome_deacon`, `jane_frances_de_chantal`, `pontian_and_hippolytus`

- [ ] Run the nine standard execution requirements with `--batch 8` and require every gate to pass.
- [ ] Commit only Batch 8 files with the following command.

Commit: `git commit -m "content: research saints batch 8"`

### Task 10: Publish Batch 9 — August and early September

**Profiles:** `the_assumption_of_the_blessed_virgin_mary`, `stephen_of_hungary`, `john_eudes`, `queenship_of_blessed_virgin_mary`, `rose_of_lima`, `bartholomew_apostle`, `joseph_of_calasanz`, `louis_ix_of_france`, `passion_of_john_the_baptist`, `nativity_of_blessed_virgin_mary`, `peter_claver`, `most_holy_name_of_mary`

- [ ] Run the nine standard execution requirements with `--batch 9` and require every gate to pass.
- [ ] Commit only Batch 9 files with the following command.

Commit: `git commit -m "content: research saints batch 9"`

### Task 11: Publish Batch 10 — September and early October

**Profiles:** `our_lady_of_sorrows`, `robert_bellarmine`, `januarius_of_benevento`, `matthew_apostle`, `cosmas_and_damian`, `lawrence_ruiz`, `wenceslaus_of_bohemia`, `faustina_kowalska`, `bruno_of_cologne`, `our_lady_of_the_rosary`, `denis_of_paris`, `john_leonardi`

- [ ] Run the nine standard execution requirements with `--batch 10` and require every gate to pass.
- [ ] Commit only Batch 10 files with the following command.

Commit: `git commit -m "content: research saints batch 10"`

### Task 12: Publish Batch 11 — October

**Profiles:** `john_xxiii_pope`, `our_lady_of_aparecida`, `callistus_i_pope`, `hedwig_of_silesia`, `margaret_mary_alacoque`, `luke_evangelist`, `john_de_brebeuf_and_isaac_jogues`, `paul_of_the_cross`, `john_paul_ii_pope`, `john_of_capistrano`, `anthony_mary_claret`, `simon_and_jude_apostles`

- [ ] Run the nine standard execution requirements with `--batch 11` and require every gate to pass.
- [ ] Commit only Batch 11 files with the following command.

Commit: `git commit -m "content: research saints batch 11"`

### Task 13: Publish Batch 12 — November and early December

**Profiles:** `albert_the_great`, `gertrude_the_great`, `margaret_of_scotland`, `dedication_of_basilicas_of_peter_and_paul`, `presentation_of_blessed_virgin_mary`, `clement_i_pope`, `columban_of_luxeuil`, `catherine_of_alexandria`, `andrew_apostle`, `john_damascene`, `nicholas_of_myra`, `the_immaculate_conception_of_the_blessed_virgin_mary`

- [ ] Run the nine standard execution requirements with `--batch 12` and require every gate to pass.
- [ ] Commit only Batch 12 files with the following command.

Commit: `git commit -m "content: research saints batch 12"`

### Task 14: Publish Batch 13 — December and the Holy Family

**Profiles:** `juan_diego`, `our_lady_of_loreto`, `damasus_i_pope`, `our_lady_of_guadalupe`, `peter_canisius`, `john_of_kanty`, `stephen_first_martyr`, `john_apostle`, `holy_innocents`, `thomas_becket`, `sylvester_i_pope`, `holy_family`

- [ ] Run the nine standard execution requirements with `--batch 13` and require every gate to pass.
- [ ] Commit only Batch 13 files with the following command.

Commit: `git commit -m "content: research saints batch 13"`

### Task 15: Publish Batch 14 — variable-date Marian celebrations

**Profiles:** `immaculate_heart_of_mary`, `mary_mother_of_the_church`

- [ ] Run the nine standard execution requirements with `--batch 14` and require every gate to pass.
- [ ] Verify movable-date calendar resolution in addition to profile content:

Run: `flutter test test/data/services/saint_profile_service_test.dart test/data/services/liturgical_region_rules_test.dart`

Expected: PASS and both celebrations resolve on representative 2026 dates.

- [ ] Commit only Batch 14 files: `git commit -m "content: research variable-date Marian profiles"`

### Task 16: Cut over to the authoritative v2 corpus

**Files:**
- Modify: `lib/data/services/saint_profile_repository.dart`
- Modify: `lib/data/services/saint_profile_service.dart`
- Modify: `pubspec.yaml`
- Delete: `assets/data/saints_profiles.json`
- Modify: repository, service, validator, queue, and legacy coverage tests

- [ ] **Step 1: Prove all 158 profiles are published before deletion**

Run:

```powershell
dart run tool/saint_research_queue.dart
dart run tool/validate_saint_profiles.dart
```

Expected: `158/158 published`, zero unknown/duplicate/missing dossier IDs, zero validation errors. Stop if this is not exact.

- [ ] **Step 2: Write the failing v2-only repository test**

Assert that production loading succeeds from the index without a legacy asset, that the index contains exactly 158 unique IDs, and that every celebration mapping from the existing calendar coverage test resolves to a published full guide.

- [ ] **Step 3: Remove the legacy dependency**

Make the v2 index authoritative: load every indexed profile, reject duplicate IDs, require schema version 2, validate the complete corpus, and cache only a successful 158-profile result. Remove the legacy parser, asset entry, file, fallback biography builder for curated celebration IDs, and migration-only CLI flags. Keep the generic missing-profile UI for future calendar additions that do not yet have curated data.

- [ ] **Step 4: Update corpus assertions**

Replace “greater than or equal to 150” and non-empty brief-bio checks with exact assertions:

```dart
expect(profiles, hasLength(158));
expect(profiles.every((profile) => profile.isPublished), isTrue);
expect(profiles.every((profile) => profile.hasFullGuide), isTrue);
expect(SaintProfileValidator().validateCorpus(profiles), isEmpty);
```

- [ ] **Step 5: Run complete verification**

Run:

```powershell
dart run tool/saint_research_queue.dart
dart run tool/validate_saint_profiles.dart
flutter analyze
flutter test
flutter build apk --debug
```

Expected: every command exits 0; queue reports 158/158; validator reports zero errors; APK exists.

- [ ] **Step 6: Perform final emulator sampling**

Open at least one profile from every profile kind, one ancient/legendary profile, one modern saint, one group, one African saint, one Marian celebration, and both variable-date profiles. Verify offline mode, dynamic text, dark theme, source sheets, and absence of legacy placeholder UI.

- [ ] **Step 7: Commit the corpus cutover**

```powershell
git add lib/data/services/saint_profile_repository.dart lib/data/services/saint_profile_service.dart pubspec.yaml assets/data/saints/index.json tool/validate_saint_profiles.dart tool/saint_research_queue.dart test/data/legacy_data_coverage_test.dart test/data/services/saint_profile_repository_test.dart test/data/services/saint_profile_validator_test.dart test/data/services/saint_profile_service_test.dart test/tool/saint_research_queue_test.dart
git rm assets/data/saints_profiles.json
git commit -m "feat: publish complete researched saint corpus"
```
