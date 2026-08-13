# Saint Profiles Batch 12 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade twelve late-November and early-December legacy records into researched schema-v2 profiles with complete dossiers, exact provenance, safe pastoral framing, and correct person/group/observance UI behavior.

**Architecture:** Each stable legacy ID receives one JSON overlay and one matching research dossier. Three four-profile content tasks are independently reviewed before a batch-wide integrity, regression, and release task.

**Tech Stack:** Flutter/Dart, schema-v2 JSON assets, Markdown research dossiers, `SaintProfileValidator`, deterministic queue tooling, service/widget tests, Git worktrees.

---

## Binding acceptance rules

- Read at least three credible actual sources where available, including primary/formal evidence and independent scholarship. Catalog or discovery metadata alone is not content evidence.
- Preserve exact JSON/dossier equality across source ID, tier, author/institution, title, publisher, URL, access date, and reuse basis; locate material claims precisely and wire every source reference.
- Preserve stable IDs and valid celebration aliases; live-check Wikidata mappings. Summaries must be 100–150 words; profiles publish at revision 1 with review date 2026-08-13.
- Distinguish documented, received, traditional, legendary, disputed, and mixed claims. Avoid unsupported precision, popular quotations, copied modern prose, or image reuse without file-level rights.
- Treat Marian doctrine, antisemitism, anti-Muslim rhetoric, crusade, war, nationalism, illness, disability, medicine, family, sexuality, spiritual authority, private revelation, miracle claims, martyrdom, and torture with explicit safeguards.
- Feasts or dedications that are not particular human biographies must be `observance` profiles with no lifespan/lifeLength/vocation/person simulation. Groups receive no synthetic shared lifespan or person-only QID.
- Patronage and symbols require reviewed formal evidence and exact compatible tokens. Calendar title/date/rank and GIRM color evidence must be represented separately unless a source explicitly supplies both.
- Every dossier records rank/color and the exact observed published-validator result.

## Task 1: Learning, contemplative friendship, royal reform, and basilica dedication

**Profiles:** `albert_the_great`, `gertrude_the_great`, `margaret_of_scotland`, `dedication_of_basilicas_of_peter_and_paul`

- [ ] Capture exact four-ID RED before edits.
- [ ] Research Albert through authenticated works/critical editions, Dominican and university history, science/natural philosophy, episcopal leadership, Thomas Aquinas reception, and later cult. Avoid anachronistic scientist myths, magic/alchemy legend, unsafe medical inference, and intellectual triumphalism.
- [ ] Research Gertrude through authenticated manuscript/corpus controls, Helfta community and women’s intellectual agency, independent medieval scholarship, health, visions, and Sacred Heart reception. Private revelation is not public Revelation; reject magical promises, coercive direction, self-harm, body shame, and retrospective diagnosis.
- [ ] Research Margaret of Scotland through near-contemporary/critical sources and independent medieval scholarship on marriage, children, court reform, charity, war, illness, death, and Scottish/Hungarian reception. Preserve women’s and recipients’ agency; reject monarchy, nationalism, coerced family roles, and unsafe fasting/grief models.
- [ ] Model the Dedication of the Basilicas of Saints Peter and Paul as an observance. Research archaeological/building history, distinct basilicas and dedications, apostolic tomb/relic claims, liturgical reception, and later rebuilding. Do not simulate a joint human biography, merge the two apostles/sites, or treat archaeology, relics, indulgence, or pilgrimage as guaranteed proof/protection.
- [ ] Create four JSON/dossier pairs plus index; validate, audit parity/refs/QIDs/calendar/arrays/summaries, run focused tests, and commit `content: research learning and dedication profiles`.
- [ ] Obtain independent specification and content/source PASSes before Task 2.

## Task 2: Marian presentation, Roman memory, missionary encounter, and disputed martyr legend

**Profiles:** `presentation_of_blessed_virgin_mary`, `clement_i_pope`, `columban_of_luxeuil`, `catherine_of_alexandria`

- [ ] Capture exact four-ID RED before edits.
- [ ] Model the Presentation of Mary as an observance through canonical silence, the Protoevangelium and later reception, liturgical history, Marian doctrine, and independent apocrypha scholarship. Do not simulate Mary’s childhood biography, treat temple scenes as eyewitness fact, impose gender/purity roles, or promise fertility/protection.
- [ ] Research Clement through the authentic letter of 1 Clement, early Roman reception, succession evidence, authorship/community questions, later exile/martyr/anchor/relic traditions, and critical scholarship. Do not turn later legend into biography or use order/obedience language to conceal abuse or suppress conscience.
- [ ] Research Columban through authenticated letters/rules/sermons and monastic archives plus independent scholarship on migration, Irish/Frankish/Lombard politics, penitential discipline, controversy, illness, and cult. Reject coercive penance, harmful obedience, unsafe asceticism, anti-Jewish readings, and nationalist ownership.
- [ ] Research Catherine through earliest cult/textual evidence, critical legend and gender scholarship, Alexandria context, later crusade/monastic/educational reception, and absence of secure contemporary biography. Avoid graphic torture, anti-pagan triumphalism, forced-debate stereotypes, miracle proof, and unsafe martyr imitation.
- [ ] Create four JSON/dossier pairs plus index; validate, audit parity/refs/QIDs/calendar/arrays/summaries, run focused tests, and commit `content: research tradition and conscience profiles`.
- [ ] Obtain independent specification and content/source PASSes before Task 3.

## Task 3: Apostolic witness, theological controversy, popular generosity, and Marian doctrine

**Profiles:** `andrew_apostle`, `john_damascene`, `nicholas_of_myra`, `the_immaculate_conception_of_the_blessed_virgin_mary`

- [ ] Capture exact four-ID RED before edits.
- [ ] Ground Andrew in canonical texts and early reception while separating apostle identity, Peter relationship, call narratives, mission/death/relic traditions, cross iconography, and national patronage. Avoid synthetic chronology, conquest/national possession, graphic martyrdom, and relic certainty.
- [ ] Research John Damascene through authenticated works/critical editions and independent Byzantine/Umayyad scholarship on family/governance context, icon controversy, Christology, Islam-related texts, monastic reception, and death chronology. Reject anti-Muslim polemic, icon magic, false eyewitness claims, and anachronistic career certainty.
- [ ] Research Nicholas through early cult/archaeological/textual evidence, critical hagiography, Myra and Bari relic reception, gift-giving development, and modern Santa traditions. Separate historical bishop memory from later legends; reject miracle/wealth promises, coercive charity, consumerism, and nationalist/relic ownership.
- [ ] Model the Immaculate Conception as an observance through `Ineffabilis Deus`, Scripture and doctrinal reception, medieval theological controversy, Eastern/Western distinctions, liturgical history, and independent scholarship. Do not simulate Mary’s conception/gestation biography, confuse it with Jesus’ virginal conception, or imply sexuality/body/pregnancy shame, medical guarantee, or anti-Jewish supersession.
- [ ] Create four JSON/dossier pairs plus index; validate, audit parity/refs/QIDs/calendar/arrays/summaries, run focused tests, and commit `content: research apostolic and doctrinal profiles`.
- [ ] Obtain independent specification and content/source PASSes before Task 4.

## Task 4: Batch-wide integrity and release

- [ ] Run `dart run tool/saint_research_queue.dart --batch 12`; expect 144/158 published and all twelve requested profiles valid.
- [ ] Run `dart run tool/validate_saint_profiles.dart --published-only`; expect 144 researched/validated and zero errors/warnings.
- [ ] Audit every source ledger and material claim, live URL/QID, alias, rank/color, kind, lifespan, summary, formal array, observance/group omission, safeguard, originality, and media decision.
- [ ] Add real-asset UI regressions for every Batch 12 observance/group profile, with representative individuals remaining person-centered. Add twelve-profile summary, identity/kind/QID, and rank/color regressions.
- [ ] Run focused tests, `flutter analyze --no-pub`, the full serialized `flutter test --no-pub --concurrency=1`, and range diff/scope/status checks. Correct only confirmed in-scope defects.
- [ ] Commit `content: audit saint research batch 12`, obtain a final independent whole-range release review, and correct/re-review every Critical or Important finding before integration.
