# Saint Profiles Batch 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade the twelve Batch 2 legacy saint records into individually researched, spiritually specific, schema-v2 published profiles with complete dossiers and claim-level provenance.

**Architecture:** Each profile is an independent JSON overlay under `assets/data/saints/profiles/` plus a matching editorial dossier under `docs/research/saints/dossiers/`. The existing repository overlays these records on the legacy corpus, while the validator and research-queue gate prevent incomplete or untraceable content from being published. Work is split into three non-overlapping four-profile groups, followed by a batch-wide integrity review.

**Tech Stack:** Flutter/Dart, JSON assets, Markdown dossiers, official Church and reliable historical web sources, `SaintProfileValidator`, `SaintResearchDossierGate`.

---

## Binding acceptance rules for every profile in this plan

Every implementer must apply all of these rules to every assigned profile:

- Read at least three credible sources when three exist. Include an official or primary Catholic source where accessible; use reputable historical references to control chronology and tradition.
- Browse and read the actual source pages. Search-result snippets, Wikipedia summaries, Wikidata, and legacy app prose are not sufficient evidence.
- Write original prose. Do not closely paraphrase source articles, reproduce liturgical collects, or include an unverified quotation.
- Classify material as documented, reliably traditional, legendary, disputed, or mixed. Omit unsupported precision.
- Make `whyItMatters`, every virtue, both practices, both questions, Scripture connection, and prayer specific enough that substituting another saint's name would make the text false.
- For martyrs and violence, remain accurate and non-graphic. Do not imply that abuse or execution was spiritually good.
- For Marian and biblical profiles, use the appropriate profile kind and do not invent a human-style biography or lifespan where it does not apply.
- Use at least two populated dossier source rows, exact dossier/profile source-ID equality, populated claim rows with valid source references, separate content and theological review statements, and no image unless file-specific licensing is fully documented.
- Set editorial state to `published`, revision `1`, reviewed date `2026-08-10`, researcher `Catholic Daily editorial research`, reviewer `Catholic Daily factual and theological review`, and an empty warnings list only after the profile and dossier are complete.

## Task 1: January pastors and martyrs

**Profiles:** `raymond_of_penyafort`, `hilary_of_poitiers`, `fabian_i_pope`, `sebastian_of_milan`

**Files:**

- Create: `assets/data/saints/profiles/raymond_of_penyafort.json`
- Create: `assets/data/saints/profiles/hilary_of_poitiers.json`
- Create: `assets/data/saints/profiles/fabian_i_pope.json`
- Create: `assets/data/saints/profiles/sebastian_of_milan.json`
- Create: `docs/research/saints/dossiers/raymond_of_penyafort.md`
- Create: `docs/research/saints/dossiers/hilary_of_poitiers.md`
- Create: `docs/research/saints/dossiers/fabian_i_pope.md`
- Create: `docs/research/saints/dossiers/sebastian_of_milan.md`
- Modify: `assets/data/saints/index.json`

- [ ] **Step 1: Record the red gate**

Run:

```powershell
dart run tool/saint_research_queue.dart --ids raymond_of_penyafort,hilary_of_poitiers,fabian_i_pope,sebastian_of_milan
```

Expected: exit 1 with `researched JSON is not indexed` for all four IDs.

- [ ] **Step 2: Resolve identity and evidence**

Read the four corresponding objects in `assets/data/saints_profiles.json` and their calendar rows. Research each subject independently. Prioritize Raymond's Dominican/order and canonical-law sources; Hilary's patristic/Doctor-of-the-Church sources; and early Roman historical/liturgical sources for Fabian and Sebastian. Record exact URLs, access dates, source tier, supported claims, conflicts, and rejected precision before drafting.

- [ ] **Step 3: Write four complete dossiers**

Create each Markdown dossier with the exact identity, source-ledger, claim-ledger, copyright/media, content-review, theological-review, and final-validation sections required by `docs/research/saints/README.md`. Source rows must exactly match that profile's JSON source IDs. Explicitly separate securely documented history from early tradition for Fabian and Sebastian.

- [ ] **Step 4: Write four schema-v2 profiles**

Use `assets/data/saints/profiles/josephine_bakhita.json` as the structural reference, not as a prose template. Preserve the stable legacy ID and all valid celebration IDs. Supply profile-kind-appropriate identity fields, original short and long guides, 3–5 sourced life sections where evidence permits, one to three evidence-linked virtues, a spiritual practice, a concrete action, two reflection questions, Scripture companion, and original Christ-centred prayer.

- [ ] **Step 5: Index the four overlays**

Add the four new paths exactly once to `assets/data/saints/index.json`, retaining valid JSON and the existing published entries.

- [ ] **Step 6: Verify green**

Run:

```powershell
dart run tool/validate_saint_profiles.dart --published-only
dart run tool/saint_research_queue.dart --ids raymond_of_penyafort,hilary_of_poitiers,fabian_i_pope,sebastian_of_milan
git diff --check
```

Expected: zero validator errors/warnings, research gate PASS, and clean diff check.

- [ ] **Step 7: Commit**

```powershell
git add assets/data/saints/index.json assets/data/saints/profiles/raymond_of_penyafort.json assets/data/saints/profiles/hilary_of_poitiers.json assets/data/saints/profiles/fabian_i_pope.json assets/data/saints/profiles/sebastian_of_milan.json docs/research/saints/dossiers/raymond_of_penyafort.md docs/research/saints/dossiers/hilary_of_poitiers.md docs/research/saints/dossiers/fabian_i_pope.md docs/research/saints/dossiers/sebastian_of_milan.md
git commit -m "content: research January saint profiles"
```

## Task 2: Conversion, service, and mission

**Profiles:** `vincent_of_saragossa`, `conversion_of_saint_paul`, `angela_merici`, `ansgar_of_hamburg`

**Files:**

- Create: `assets/data/saints/profiles/vincent_of_saragossa.json`
- Create: `assets/data/saints/profiles/conversion_of_saint_paul.json`
- Create: `assets/data/saints/profiles/angela_merici.json`
- Create: `assets/data/saints/profiles/ansgar_of_hamburg.json`
- Create: matching files under `docs/research/saints/dossiers/`
- Modify: `assets/data/saints/index.json`

- [ ] **Step 1: Record the red gate**

Run:

```powershell
dart run tool/saint_research_queue.dart --ids vincent_of_saragossa,conversion_of_saint_paul,angela_merici,ansgar_of_hamburg
```

Expected: exit 1 because the four researched overlays are absent.

- [ ] **Step 2: Research the four identities and conflicts**

For Vincent, distinguish early martyr tradition from later legendary elaboration. For Paul's conversion, ground the biblical profile in Acts and Paul's own letters and reconcile the different narrative emphases without inventing a single cinematic reconstruction. For Angela, prioritize official Ursuline/Church material and reliable chronology. For Ansgar, use strong historical and ecclesial sources while avoiding triumphalist treatment of mission or uncertain miracle traditions.

- [ ] **Step 3: Create dossiers with exact ledgers**

For every material claim, list the supporting source IDs and certainty. Include separate review passages that check historical accuracy, pastoral safety, Christ-centred theology, treatment of conversion and mission, and the originality of all prose and prayers.

- [ ] **Step 4: Create schema-v2 profiles**

Use `biblical` for the Conversion of Saint Paul and the historically appropriate kind for the other three. Do not give the conversion observance an artificial new lifespan; connect its guide to Paul's documented life and the celebration's meaning. Write specific practices: conversion as truthful response and repair, Angela's patient formation of women, Ansgar's perseverance without coercion, and Vincent's fidelity without sensationalizing torture.

- [ ] **Step 5: Index and verify**

Add all four profile paths once, then run:

```powershell
dart run tool/validate_saint_profiles.dart --published-only
dart run tool/saint_research_queue.dart --ids vincent_of_saragossa,conversion_of_saint_paul,angela_merici,ansgar_of_hamburg
git diff --check
```

Expected: zero validator errors/warnings, gate PASS, clean diff check.

- [ ] **Step 6: Commit**

```powershell
git add assets/data/saints/index.json assets/data/saints/profiles/vincent_of_saragossa.json assets/data/saints/profiles/conversion_of_saint_paul.json assets/data/saints/profiles/angela_merici.json assets/data/saints/profiles/ansgar_of_hamburg.json docs/research/saints/dossiers/vincent_of_saragossa.md docs/research/saints/dossiers/conversion_of_saint_paul.md docs/research/saints/dossiers/angela_merici.md docs/research/saints/dossiers/ansgar_of_hamburg.md
git commit -m "content: research conversion and mission profiles"
```

## Task 3: Healing, mercy, and religious communities

**Profiles:** `blaise_of_sebaste`, `jerome_emiliani`, `our_lady_of_lourdes`, `seven_holy_founders_of_servites`

**Files:**

- Create: `assets/data/saints/profiles/blaise_of_sebaste.json`
- Create: `assets/data/saints/profiles/jerome_emiliani.json`
- Create: `assets/data/saints/profiles/our_lady_of_lourdes.json`
- Create: `assets/data/saints/profiles/seven_holy_founders_of_servites.json`
- Create: matching files under `docs/research/saints/dossiers/`
- Modify: `assets/data/saints/index.json`

- [ ] **Step 1: Record the red gate**

Run:

```powershell
dart run tool/saint_research_queue.dart --ids blaise_of_sebaste,jerome_emiliani,our_lady_of_lourdes,seven_holy_founders_of_servites
```

Expected: exit 1 because the four researched overlays are absent.

- [ ] **Step 2: Research with subject-specific safeguards**

For Blaise, distinguish sparse historical evidence from the throat-blessing tradition and make no medical promises. For Jerome, document imprisonment, conversion, service to vulnerable children, and the Somaschi without romanticizing trauma. For Lourdes, use `marian`, separate the Immaculate Conception doctrine, Bernadette's reported apparitions, Church recognition, pilgrimage, and medical claims; do not guarantee healing. For the Seven Founders, treat the group identity and Servite tradition without fabricating seven parallel biographies.

- [ ] **Step 3: Create complete dossiers and profiles**

Use exact source and claim ledgers, explicit certainty, original prose, and profile-kind-appropriate life sections. Practices must prioritize responsible care: prayer alongside medical care for Blaise and Lourdes, safeguarding and competent service for Jerome, and reconciliation/community discernment for the Servite founders.

- [ ] **Step 4: Index and verify**

Add all four profile paths once, then run:

```powershell
dart run tool/validate_saint_profiles.dart --published-only
dart run tool/saint_research_queue.dart --ids blaise_of_sebaste,jerome_emiliani,our_lady_of_lourdes,seven_holy_founders_of_servites
git diff --check
```

Expected: zero validator errors/warnings, gate PASS, clean diff check.

- [ ] **Step 5: Commit**

```powershell
git add assets/data/saints/index.json assets/data/saints/profiles/blaise_of_sebaste.json assets/data/saints/profiles/jerome_emiliani.json assets/data/saints/profiles/our_lady_of_lourdes.json assets/data/saints/profiles/seven_holy_founders_of_servites.json docs/research/saints/dossiers/blaise_of_sebaste.md docs/research/saints/dossiers/jerome_emiliani.md docs/research/saints/dossiers/our_lady_of_lourdes.md docs/research/saints/dossiers/seven_holy_founders_of_servites.md
git commit -m "content: research healing and community profiles"
```

## Task 4: Batch-wide integrity and release gate

**Files:**

- Inspect: all twelve Batch 2 JSON profiles and dossiers
- Modify only if review finds a concrete defect

- [ ] **Step 1: Run the exact batch gate**

```powershell
dart run tool/saint_research_queue.dart --batch 2
```

Expected: `Research gate PASS` for all twelve profiles.

- [ ] **Step 2: Run corpus validation**

```powershell
dart run tool/validate_saint_profiles.dart --published-only
```

Expected: 24 researched and validated profiles, zero errors, zero warnings.

- [ ] **Step 3: Inspect originality and evidence coverage**

Compare the twelve profiles for repeated `whyItMatters`, biography, virtue, imitation, practice, question, or prayer phrasing. Confirm every JSON source exists in the dossier, every dossier source is in JSON, every life section and virtue has valid source IDs, and every uncertainty classification agrees with the wording shown to users.

- [ ] **Step 4: Run application verification**

```powershell
flutter analyze
flutter test test/data/models/saint_profile_v2_test.dart test/data/services/saint_profile_repository_test.dart test/data/services/saint_profile_validator_test.dart test/tool/saint_research_queue_test.dart test/ui/screens/saint_detail_screen_test.dart
git diff --check
```

Expected: analysis clean, focused tests pass, diff check clean.

- [ ] **Step 5: Commit review corrections if needed**

```powershell
git add assets/data/saints docs/research/saints
git commit -m "content: review saint research batch 2"
```

Skip this commit only when the review produces no file changes.
