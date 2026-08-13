# Saint Profiles Batch 14 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the 158-profile research queue by publishing rigorous observance profiles for the Immaculate Heart of Mary and Mary, Mother of the Church, then audit the entire researched corpus.

**Architecture:** Each final legacy ID receives one schema-v2 JSON overlay and one matching research dossier. A single content task receives independent specification and source-quality reviews, followed by corpus-wide integrity and release verification at 158/158.

**Tech Stack:** Flutter/Dart, schema-v2 JSON assets, Markdown research dossiers, `SaintProfileValidator`, deterministic queue tooling, service/widget tests, Git worktrees.

---

## Binding acceptance rules

- Read at least three credible actual sources per profile, including primary/formal evidence and independent scholarship; catalog metadata alone is not content evidence.
- Preserve exact JSON/dossier equality across source ID, tier, author/institution, title, publisher, URL, access date, and reuse basis; locate every material claim and wire every source reference.
- Preserve stable IDs and aliases; live-check Wikidata semantics. Summaries must be 100–150 words; profiles publish at revision 1 with review date 2026-08-13.
- Both records are `observance` profiles: no lifespan, lifeLength, vocation, person places, or simulated Marian biography. Use event/observance QIDs only; reject adjacent title/devotion QIDs when no exact feast item exists.
- Distinguish Scripture, doctrine, liturgical history, private revelation, devotional development, and modern reception. Avoid unsupported precision, quotations, copied prose, and media without file-level rights.
- Treat sexuality/body language, private revelation, conversion, consecration, family roles, motherhood, gender, fertility, peace/war, nationalism, and medical claims with explicit safeguards.
- Patronage and symbols require reviewed formal evidence and exact compatible tokens. Rank/date and GIRM color require separate formal controls unless one source explicitly supplies both.
- Every dossier records the exact RED, rank/color, identity conflicts, copyright/media decision, content/theological reviews, and exact observed validator result.

## Task 1: Marian heart devotion and ecclesial motherhood

**Profiles:** `immaculate_heart_of_mary`, `mary_mother_of_the_church`

- [ ] Capture exact two-ID RED using `dart run tool/saint_research_queue.dart --ids immaculate_heart_of_mary,mary_mother_of_the_church`; expect 156/158 and two unindexed-profile failures.
- [ ] Model the Immaculate Heart as an observance. Research biblical heart language and Marian reception, early-modern devotional development, the 1944 universal feast, postconciliar calendar placement after the Sacred Heart, `Marialis Cultus`, modern liturgical texts, and independent historical scholarship. Separate public doctrine/liturgy from Fatima and other private-revelation reception. Reject anatomical or sexual/body shame, magical promises, compulsory consecration, guaranteed conversion/peace/health, war-nationalist ownership, and using devotion instead of care or action.
- [ ] Model Mary, Mother of the Church as an observance. Research Gospel/Acts and conciliar ecclesiology, Paul VI’s 1964 proclamation, `Lumen Gentium`, the 2018 decree and proper texts for Monday after Pentecost, Nigeria/local calendar implementation, patristic and independent theological history, and reception of the title. Distinguish Mary’s motherhood of Christ and ecclesial title from biological motherhood of individual believers. Reject gender essentialism, compulsory maternity/fertility, exclusion of nontraditional families, clerical or institutional abuse concealment, anti-Protestant triumphalism, and treating metaphor as medical or genealogical fact.
- [ ] Create two JSON/dossier pairs and append exactly two index paths. Verify aliases, kinds, live QIDs, person-field omissions, formal arrays, movable dates/ranks/colors, source8 parity, claim/reference closure, summaries, rights, and originality.
- [ ] Run exact queue and published validator expecting 158/158 with zero errors/warnings, plus focused model/service/queue/UI tests and diff/scope checks.
- [ ] Commit `content: complete Marian observance profiles` only after independent specification and content/source PASSes.

## Task 2: Corpus-wide completion and release

- [ ] Audit the entire index for exactly 158 unique published profile paths and all 158 legacy IDs represented once.
- [ ] Run `dart run tool/saint_research_queue.dart --batch 14` and the unfiltered queue; expect `158/158 published, 0 in progress, 0 remaining` and requested-batch PASS.
- [ ] Run `dart run tool/validate_saint_profiles.dart --published-only`; expect 158 researched, 158 validated, zero errors, zero warnings.
- [ ] Audit both final dossiers and corpus-wide source/reference integrity, identity/QID/kind/lifespan omissions, aliases, summaries, formal arrays, rank/color, safeguards, originality, and media decisions.
- [ ] Add Batch 14 real-asset UI regressions for both observances, two-profile identity/QID/kind/summary/rank-color service regressions, and a corpus-completion regression asserting all 158 profiles publish without legacy fallback.
- [ ] Run focused tests, `flutter analyze --no-pub`, full serialized `flutter test --no-pub --concurrency=1`, and range diff/scope/status checks; correct only confirmed in-scope defects.
- [ ] Commit `content: complete saint research corpus`, obtain final independent whole-corpus release reviews, and correct/re-review every Critical or Important finding before integration.
