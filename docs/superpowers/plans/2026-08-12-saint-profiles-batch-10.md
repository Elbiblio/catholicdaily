# Saint Profiles Batch 10 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade twelve September and early-October legacy records into researched schema-v2 profiles with complete dossiers, claim-level provenance, safe pastoral framing, and correct person/group/observance UI behavior.

**Architecture:** Each stable legacy ID receives one independently reviewable JSON overlay and one matching Markdown research dossier. Work proceeds in three four-profile content tasks followed by a batch-wide integrity and UI-regression task; every content task must pass independent specification and content/source reviews before the next task starts.

**Tech Stack:** Flutter/Dart, schema-v2 JSON assets, Markdown research dossiers, `SaintProfileValidator`, the deterministic research queue, widget/service tests, Git worktrees.

---

## Binding acceptance rules

- Read at least three credible actual sources where available, combining primary/formal Catholic evidence with independent scholarship or recognized historical controls. Discovery pages and catalog metadata alone are not content evidence.
- Tier by genre, write original prose, omit unsupported precision and quotations, and label documented, traditional, legendary, disputed, or mixed claims.
- Maintain exact JSON/dossier equality for source ID, tier, author/institution, title, publisher, URL, access date, and reuse basis. Every material claim and formal array needs represented support.
- Preserve stable IDs and valid celebration aliases; live-check every stored Wikidata entity. Keep summaries at 100–150 words and editorial metadata published/revision 1/reviewed 2026-08-12.
- Treat grief, illness, disability, medicine, martyrdom, torture, political power, war, ethnic or religious hostility, colonialism, race, poverty, family duties, private revelation, sacramentals, and Marian devotion safely. Never spiritualize abuse, domination, preventable suffering, unsafe asceticism, or medical neglect.
- `our_lady_of_sorrows` and `our_lady_of_the_rosary` are `observance` profiles. Omit lifespan/lifeLength/vocation/person biography and center what the Church celebrates, Scripture, doctrine, liturgical history, reception, and concrete practice.
- Model paired or collective memorials as groups when the celebration is genuinely collective; do not assign a person-only QID or synthetic shared lifespan.
- Patronage and symbols require reviewed formal evidence and exact compatible tokens. No image without file-specific licensing. Every dossier records calendar rank/color and the exact observed published-validator result.

## Task 1: Marian sorrow, teaching, martyr memory, and apostolic reception

**Profiles:** `our_lady_of_sorrows`, `robert_bellarmine`, `januarius_of_benevento`, `matthew_apostle`

- [ ] Run `dart run tool/saint_research_queue.dart --ids our_lady_of_sorrows,robert_bellarmine,januarius_of_benevento,matthew_apostle` before edits and record the exact RED result.
- [ ] Model Our Lady of Sorrows as an observance through Scripture, the Paschal mystery, compassion, liturgical history, and bounded devotional reception. Do not simulate Mary’s biography, quantify pain, romanticize bereavement, promise protection, or treat private visions or art as event evidence.
- [ ] Research Robert Bellarmine through securely attributed works/critical editions, Jesuit and formal Church records, early-modern controversy, political theology, Galileo reception, and independent scholarship. Distinguish doctrine from coercive confessional politics and reject anti-Protestant triumphalism or unquestioning authority.
- [ ] Research Januarius through the earliest cult, liturgical reception, archaeology or documentary controls, later Passion traditions, and the blood relic’s recorded history. Do not present liquefaction as scientific proof, a guaranteed omen, or a substitute for medicine and public safety.
- [ ] Ground Matthew in canonical Gospel/apostle lists and source-critical reception. Separate Matthew the apostle, Matthew the tax collector, Gospel authorship, mission fields, martyrdom, relic, and iconographic traditions wherever the evidence does not securely identify them.
- [ ] Create four JSON/dossier pairs and index them exactly once; run validator, exact queue, parity/ref checks, focused tests, and diff checks.
- [ ] Commit only the task files with `content: research sorrow and witness profiles`, then obtain independent spec and content/source PASSes.

## Task 2: Healing, martyrdom, political responsibility, and private revelation

**Profiles:** `cosmas_and_damian`, `lawrence_ruiz`, `wenceslaus_of_bohemia`, `faustina_kowalska`

- [ ] Capture exact four-ID RED before edits.
- [ ] Model Cosmas and Damian according to the celebration’s actual collective scope, with no synthetic shared lifespan unless securely supportable. Separate ancient cult from later medical biographies and miracle legends; prayer never replaces licensed healthcare, consent, infection control, or evidence-based treatment.
- [ ] Research Lawrence Ruiz and companions through trial/martyr records, formal reception, Philippine/Japanese historical scholarship, migration and colonial context. Preserve companion agency, avoid graphic torture, nationalist ownership, anti-Japanese hostility, and danger-seeking spirituality.
- [ ] Research Wenceslaus through near-contemporary and critical medieval evidence, rule, kinship conflict, Christianization, violence, cult, and later nationalist/state appropriation. Canonization must not bless monarchy, fratricidal legend, coercion, war, or ethnic entitlement.
- [ ] Research Faustina through authenticated diary/manuscript controls, congregation/Church archival records, medical and historical scholarship, and formal Divine Mercy reception. Private revelation is not public Revelation; do not diagnose retrospectively, demand obedience to harmful authority, prescribe suffering, or promise magical outcomes.
- [ ] Create four JSON/dossier pairs, index, validate, audit parity/refs/summaries/QIDs/calendar/formal arrays, and run focused tests.
- [ ] Commit only the task files with `content: research mercy and responsibility profiles`, then obtain independent spec and content/source PASSes.

## Task 3: Monastic reform, Marian prayer, martyr tradition, and pastoral renewal

**Profiles:** `bruno_of_cologne`, `our_lady_of_the_rosary`, `denis_of_paris`, `john_leonardi`

- [ ] Capture exact four-ID RED before edits.
- [ ] Research Bruno through securely attributed documentary evidence, Carthusian institutional archives/rule reception, independent medieval scholarship, and later cult. Solitude must remain accountable and health-compatible, never abandonment, coercive enclosure, self-neglect, or a response to untreated distress.
- [ ] Model Our Lady of the Rosary as an observance through Scripture, Christ-centered meditation, liturgical history, development of rosary forms, formal teaching, and contested military/political reception. Reject magic, numerical compulsion, guaranteed victory, anti-Muslim triumphalism, and biography simulation.
- [ ] Research Denis through the earliest Parisian cult and archaeological/documentary controls, Gregory of Tours and later Passions, Dionysian identity conflation, Montmartre traditions, and modern scholarship. Avoid graphic cephalophore spectacle, nationalist ownership, and treating legend as eyewitness history.
- [ ] Research John Leonardi through letters/order or institutional archives, early-modern pharmacy/priesthood context, reform, education, mission planning, and independent scholarship. Do not turn medical training into modern clinical authority or reform into coercive clerical control.
- [ ] Create four JSON/dossier pairs, index, validate, audit parity/refs/summaries/QIDs/calendar/formal arrays, and run focused tests.
- [ ] Commit only the task files with `content: research prayer and renewal profiles`, then obtain independent spec and content/source PASSes.

## Task 4: Batch-wide integrity and release

- [ ] Run `dart run tool/saint_research_queue.dart --batch 10`; expect 120/158 published and all twelve requested profiles valid.
- [ ] Run `dart run tool/validate_saint_profiles.dart --published-only`; expect 120 researched/validated and zero errors/warnings.
- [ ] Audit all source ledgers, material claims, source/support references, live URLs/QIDs, aliases, ranks/colors, kinds, lifespans, summaries, observance/group framing, safeguards, arrays, originality, and media decisions.
- [ ] Add real-asset UI regressions for Our Lady of Sorrows and Our Lady of the Rosary proving observance-centered copy and no lifespan/person headings; retain representative individual/group behavior. Add twelve-profile summary, identity/kind/QID, and calendar rank/color regressions.
- [ ] Run focused tests, `flutter analyze --no-pub`, the full serialized `flutter test --no-pub --concurrency=1`, and range diff/scope/status checks. Correct only confirmed in-scope defects.
- [ ] Commit only the audit/service/test files with `content: audit saint research batch 10`.
- [ ] Obtain a final independent whole-range release review. Correct and re-review every Critical or Important finding before integration.
