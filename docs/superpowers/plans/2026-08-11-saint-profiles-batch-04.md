# Saint Profiles Batch 4 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to execute this plan one editing task at a time, with specification and quality review after every task.

**Goal:** Upgrade the next twelve legacy records into individually researched, spiritually specific, schema-v2 published profiles with complete dossiers and claim-level provenance.

**Architecture:** Each researched record is a JSON overlay in `assets/data/saints/profiles/` with a matching dossier in `docs/research/saints/dossiers/`. The existing index loads overlays over the legacy corpus. The validator and research-queue gate enforce complete data, exact ledgers, and published-state requirements.

**Tech stack:** Flutter/Dart, JSON, Markdown, official Church and primary sources, reputable historical scholarship, `SaintProfileValidator`, and `SaintResearchDossierGate`.

---

## Binding acceptance rules

Apply every rule to every profile:

- Read at least three credible actual source pages when three exist. Use official or primary Catholic evidence where accessible and an independent scholarly or recognized historical control. Search snippets, Wikipedia, Wikidata, and legacy prose are not evidence.
- Assign source tiers by genre, not publisher prestige: formal Church documents, Scripture/primary texts, liturgical texts, decrees, and relevant diocesan/order archives are Tier 1; scholarship and recognized historical references are Tier 2; reputable tertiary summaries, including saint-of-the-day narratives, are Tier 3.
- Write original prose. Do not closely paraphrase sources, reproduce collects or long translations, or use an unverified quotation.
- Mark claims as documented, reliably traditional, legendary, disputed, or mixed. Omit unsupported precision.
- Make `whyItMatters`, virtues, both practices, both questions, Scripture connection, and prayer genuinely profile-specific and Christ-centred.
- Treat violence, coercion, religious conflict, captivity, illness, fasting, family duties, mission, colonial power, and institutional authority accurately and safely. Never present abuse, persecution, domination, or execution as spiritually good.
- Include formal patronage and symbols only when reviewed evidence establishes them and the claim ledger/source `supports` fields record them. Every nonempty patronage or symbol array also needs the exact compatibility token `patronage` or `symbols`; otherwise use empty arrays.
- Use exact dossier/profile source-ID and tier equality, populated claim rows with valid source references, substantive separate content and theological reviews, and no image without file-specific licensing.
- Preserve the stable legacy ID and all valid celebration IDs. Use the correct profile kind. Include 3–5 sourced life sections where evidence permits, 1–3 sourced virtues, a spiritual practice, a concrete action, two questions, Scripture, and an original prayer.
- Set editorial state `published`, revision `1`, `lastReviewed` `2026-08-11`, researcher `Catholic Daily editorial research`, reviewer `Catholic Daily factual and theological review`, and warnings empty only after completion.

## Task 1: Preaching, conscience, exile, and mission at cultural boundaries

**Profiles:** `vincent_ferrer`, `martin_i_pope`, `anselm_of_canterbury`, `adalbert_of_prague`

**Files:** Create the four matching JSON files in `assets/data/saints/profiles/`, four matching dossiers in `docs/research/saints/dossiers/`, and modify only `assets/data/saints/index.json` additionally.

- [ ] **Record RED:** Run the exact four-ID research queue and retain the expected absent-overlay failures.
- [ ] **Resolve identity and evidence:** For Vincent, control Great Western Schism chronology, apocalyptic preaching, reported wonders, and the harmful anti-Jewish/coercive setting; do not turn popular success into proof of every legend. For Martin I, distinguish the Lateran synod and Monothelite dispute from imperial politics, and describe arrest, mistreatment, exile, and death without glorifying abuse. For Anselm, use primary writings and scholarship, distinguish secure biography from later anecdotes, avoid reducing his atonement reasoning to punitive caricature, and hold reason, prayer, and accountable Church leadership together. For Adalbert, control repeated episcopal conflict, monastic periods, mission, and martyrdom while avoiding nationalist ownership, contempt for non-Christians, or coercive mission language.
- [ ] **Write complete dossiers and profiles:** Record conflicts, rejected precision, copyright decisions, separate factual/theological reviews, and profile-specific safeguards. Practices should emphasize truthful preaching without manipulation, conscience without factionalism, faith seeking understanding, and locally accountable non-coercive witness.
- [ ] **Index, verify, and commit:** Run the published validator, exact queue, focused tests, and diff check; commit `content: research preaching and conscience profiles`.

## Task 2: Sparse history, martyr memory, Gospel witness, and Marian discipleship

**Profiles:** `george_of_lydda`, `fidelis_of_sigmaringen`, `mark_evangelist`, `louis_grignion_de_montfort`

**Files:** Create matching JSON/dossier pairs and modify only the index additionally.

- [ ] **Record RED:** Run the exact four-ID queue and retain the expected absent-overlay failures.
- [ ] **Research with subject safeguards:** For George, separate the historically sparse martyr cult from the much later dragon narrative and avoid invented chronology. For Fidelis, use Capuchin/official evidence and historical controls for lawyer, friar, mission, and death; describe confessional violence without demonizing Reformed Christians or presenting inflammatory rhetoric as a modern model. For Mark, prioritize the canonical Gospel and early reception while distinguishing traditional authorship, Rome/Peter associations, Alexandria traditions, martyr stories, and lion symbolism by certainty. For Louis, keep Marian consecration radically Christ-centred, explain historical servitude language without endorsing domination, control mission chronology and later influence, and reject manipulative or fear-based devotion.
- [ ] **Write dossiers and profiles:** George should inspire courage without credulity; Fidelis should join conviction to peace and legal care for vulnerable people; Mark should guide attentive reception and proclamation of Christ’s Gospel; Louis should guide baptismal renewal through Mary without replacing Christ, conscience, Scripture, or sacramental life.
- [ ] **Index, verify, and commit:** Run published validator, exact queue, focused tests, and diff check; commit `content: research witness and discipleship profiles`.

## Task 3: Oceania mission, Marian observance, reforming authority, and apostolic foundations

**Profiles:** `peter_chanel`, `our_lady_mother_of_africa`, `pius_v_pope`, `philip_and_james_apostles`

**Files:** Create matching JSON/dossier pairs and modify only the index additionally.

- [ ] **Record RED:** Run the exact four-ID queue and retain the expected absent-overlay failures.
- [ ] **Research with subject safeguards:** For Peter Chanel, use mission records and independent Pacific history, distinguish documented events from martyr embellishment, name colonial and cross-cultural power dynamics, and never portray Futunan people as a hostile stereotype. For Our Lady Mother of Africa, use `observance`, omit lifespan, distinguish Marian theology from the Algiers basilica/title history, and address nineteenth-century colonial context without making devotion an instrument of domination. For Pius V, document Dominican formation, reform, liturgy, governance, Lepanto devotion, and canonization while honestly addressing inquisitorial coercion, anti-Jewish measures, confessional conflict, and institutional harm; do not equate holiness with every policy. For Philip and James, resolve whether the joint celebration is best represented as `group`, keep the two apostolic identities distinct, ground Philip in Scripture, control James son-of-Alphaeus traditions, and avoid conflating him with James the Lord’s brother without evidence.
- [ ] **Write dossiers and profiles:** Practices should emphasize culturally humble service, Marian prayer ordered to Christ and reconciliation, authority open to repentance and historical truth, and apostolic friendship that makes room for distinct vocations. Include only formally supported patronage and symbols.
- [ ] **Index, verify, and commit:** Run published validator, exact queue, focused tests, and diff check; commit `content: research mission reform and apostolic profiles`.

## Task 4: Batch-wide integrity and release gate

- [ ] Run `dart run tool/saint_research_queue.dart --batch 4`; expect PASS for all twelve.
- [ ] Run `dart run tool/validate_saint_profiles.dart --published-only`; expect 48 researched/validated profiles and zero errors/warnings.
- [ ] Audit all twelve profiles for repeated prose, claim/source support, certainty alignment, profile-kind correctness, genre-based tiers, formal metadata, safeguards, URL health, and exact source/tier equality.
- [ ] Verify every nonempty patronage/symbol array renders through exact source-support compatibility tokens.
- [ ] Run `flutter analyze`, focused profile/model/service/repository/validator/queue/UI tests, and `git diff --check`.
- [ ] Run the serialized full `flutter test` suite with a generous timeout.
- [ ] Commit concrete review corrections as `content: review saint research batch 4`; skip the commit only if no files change.

Every implementation task receives an independent specification review followed by an independent quality review. Critical and Important findings must be fixed and re-reviewed before the next task.
