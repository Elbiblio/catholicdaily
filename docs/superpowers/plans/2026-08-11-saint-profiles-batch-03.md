# Saint Profiles Batch 3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to execute this plan one editing task at a time, with specification and quality review after every task.

**Goal:** Upgrade the twelve Batch 3 legacy records into individually researched, spiritually specific, schema-v2 published profiles with complete dossiers and claim-level provenance.

**Architecture:** Each researched record is a JSON overlay in `assets/data/saints/profiles/` with a matching dossier in `docs/research/saints/dossiers/`. The existing index loads the overlays over the legacy corpus. The validator and research-queue gate enforce complete data, exact ledgers, and published-state requirements.

**Tech stack:** Flutter/Dart, JSON, Markdown, official Church and primary sources, reputable historical scholarship, `SaintProfileValidator`, and `SaintResearchDossierGate`.

---

## Binding acceptance rules

Apply every rule to every profile:

- Read at least three credible actual source pages when three exist. Use official or primary Catholic evidence where accessible and an independent scholarly or recognized historical control. Search snippets, Wikipedia, Wikidata, and legacy prose are not evidence.
- Assign source tiers by genre, not publisher prestige: formal Church documents, Scripture/primary texts, liturgical texts, decrees, and relevant diocesan/order archives are Tier 1; scholarship and recognized historical references are Tier 2; reputable tertiary summaries, including saint-of-the-day narratives, are Tier 3.
- Write original prose. Do not closely paraphrase sources, reproduce collects or long translations, or use an unverified quotation.
- Mark claims as documented, reliably traditional, legendary, disputed, or mixed. Omit unsupported precision.
- Make `whyItMatters`, virtues, both practices, both questions, Scripture connection, and prayer genuinely profile-specific and Christ-centred.
- Treat violence, captivity, illness, fasting, family duties, mission, and institutional power accurately and safely. Never present abuse, coercion, illness, trauma, or execution as spiritually good.
- Include formal patronage and symbols only when the reviewed evidence establishes them and the claim ledger/source `supports` fields record them; otherwise use empty arrays.
- Use exact dossier/profile source-ID and tier equality, populated claim rows with valid source references, substantive separate content and theological reviews, and no image without file-specific licensing.
- Preserve the stable legacy ID and all valid celebration IDs. Use the correct profile kind. Include 3–5 sourced life sections where evidence permits, 1–3 sourced virtues, a spiritual practice, a concrete action, two questions, Scripture, and an original prayer.
- Set editorial state `published`, revision `1`, `lastReviewed` `2026-08-11`, researcher `Catholic Daily editorial research`, reviewer `Catholic Daily factual and theological review`, and warnings empty only after completion.

## Task 1: Teachers, apostolic office, and the prayer of the Church

**Profiles:** `peter_damian`, `chair_of_saint_peter`, `gregory_of_narek`, `cyril_of_jerusalem`

**Files:** Create the four matching JSON files in `assets/data/saints/profiles/`, four matching dossiers in `docs/research/saints/dossiers/`, and modify only `assets/data/saints/index.json` additionally.

- [ ] **Record RED:** Run `dart run tool/saint_research_queue.dart --ids peter_damian,chair_of_saint_peter,gregory_of_narek,cyril_of_jerusalem`; expect all four overlays to be absent.
- [ ] **Resolve identity and evidence:** Read legacy/calendar rows and actual sources. For Peter Damian, control reform chronology, offices, primary writings, penitential context, and the limitations or harmful uses of severe rhetoric. For the Chair of Peter, use `observance`, distinguish the feast's theology of Petrine ministry from the physical chair/relic history, and ground Peter's commission in Scripture without inventing an observance lifespan. For Gregory, use Armenian primary/official material and strong historical control, respect Armenian ecclesial context, and avoid flattening his *Book of Lamentation* into generic wellness language. For Cyril, use the *Catechetical Lectures* and historical controls, distinguish documented episcopal conflict from later simplification, and handle polemical material responsibly.
- [ ] **Create complete dossiers:** Record exact source metadata, tier by genre, supported claims, conflicts, rejected precision, copyright decision, and separate factual/theological reviews.
- [ ] **Create schema-v2 profiles:** Use `observance` for the Chair and historically appropriate kinds for the others. Practices should emphasize accountable reform and mercy (Peter), service rather than domination in Church authority (Chair), truthful compunction joined to hope (Gregory), and patient catechesis/sacramental formation without contempt for others (Cyril).
- [ ] **Index and verify:** Add each path once, then run the published validator, exact four-ID research queue, and `git diff --check`.
- [ ] **Commit:** `content: research teachers and apostolic profiles`.

## Task 2: Royal responsibility, healing service, lay vocation, and mission

**Profiles:** `casimir_of_poland`, `john_of_god`, `frances_of_rome`, `patrick_of_ireland`

**Files:** Create matching JSON/dossier pairs and modify only the index additionally.

- [ ] **Record RED:** Run the exact four-ID queue and record the expected absent-overlay failure.
- [ ] **Research with subject safeguards:** For Casimir, control court chronology, devotional traditions, chastity claims, and formal patronage; do not confuse holiness with withdrawal from public responsibility. For John of God, distinguish documented conversion and hospital service from later dramatic stories, describe his mental-health crisis and institutional mistreatment without diagnostic speculation or romanticizing harm, and require competent professional/organizational care. For Frances, document marriage, motherhood, service, community foundation, and later religious life without implying that women must endure coercion or neglect family safety; separate visions/guardian-angel traditions from secure biography. For Patrick, prioritize the *Confessio* and *Letter to Coroticus*, distinguish slavery/captivity and mission from later snakes/shamrock legends, condemn enslavement, and frame mission without coercion or nationalist triumphalism.
- [ ] **Write dossiers and profiles:** Exact ledgers, controlled certainty, original spiritual guidance. John actions must route help through trained, safeguarded health and social-service providers. Frances practices must respect consent, vocation, family responsibilities, and safety. Patrick must connect conversion to humility, opposition to exploitation, and locally accountable witness.
- [ ] **Index, verify, and commit:** Run published validator, exact queue, diff check; commit `content: research service and mission profiles`.

## Task 3: Biblical family life, colonial-era reform, asceticism, and learning

**Profiles:** `saint_joseph_spouse_of_blessed_virgin_mary`, `turibius_of_mogrovejo`, `francis_of_paola`, `isidore_of_seville`

**Files:** Create matching JSON/dossier pairs and modify only the index additionally.

- [ ] **Record RED:** Run the exact four-ID queue and record the expected absent-overlay failure.
- [ ] **Research with subject safeguards:** Use `biblical` for Joseph, remove the corrupt legacy lifespan, stay within Matthew/Luke and received Church teaching, distinguish Scripture from later tradition, and present protective family responsibility without rigid gender stereotypes or unsafe submission. For Turibius, use primary/official and independent colonial-history controls, record his defense of Indigenous dignity and pastoral reforms while acknowledging Spanish colonial power, contested coercive structures, and institutional limits. For Francis of Paola, distinguish founder history from miracle legends; never recommend extreme fasting or ascetic practices without health, vocation, and competent spiritual safeguards. For Isidore, control his scholarship, councils, and Doctor title while honestly addressing anti-Jewish coercive measures or influence; do not turn later internet/computer patronage claims into fact without formal evidence.
- [ ] **Write dossiers and profiles:** Joseph should guide attentive obedience to God, protective care, work, and non-possessive fatherhood. Turibius should inspire accountable leadership that listens across language/culture and resists dehumanizing systems. Francis should emphasize humility, reconciliation, sustainable self-denial, and care for health. Isidore should join learning to truth, attribution, correction, and honest scrutiny of harmful legacies.
- [ ] **Index, verify, and commit:** Run published validator, exact queue, diff check; commit `content: research family reform and learning profiles`.

## Task 4: Batch-wide integrity and release gate

- [ ] Run `dart run tool/saint_research_queue.dart --batch 3`; expect PASS for all twelve.
- [ ] Run `dart run tool/validate_saint_profiles.dart --published-only`; expect 36 researched/validated profiles and zero errors/warnings.
- [ ] Inspect all twelve profiles for repeated prose, claim/source support, certainty alignment, profile-kind correctness, tier-by-genre consistency, formal metadata, pastoral safety, and exact source/tier equality.
- [ ] Run `flutter analyze`.
- [ ] Run focused profile/model/service/repository/validator/queue/UI tests and `git diff --check`.
- [ ] Run the full `flutter test` suite with a generous timeout.
- [ ] Commit concrete review corrections as `content: review saint research batch 3`; skip the commit only if no files change.

Every implementation task receives an independent specification review followed by an independent quality review. Critical and Important findings must be fixed and re-reviewed before the next task.
