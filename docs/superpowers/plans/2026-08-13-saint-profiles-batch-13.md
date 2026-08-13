# Saint Profiles Batch 13 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade twelve December and Christmas-octave legacy records into researched schema-v2 profiles with complete dossiers, exact provenance, safe pastoral framing, and correct biblical, person, group, and observance UI behavior.

**Architecture:** Each stable legacy ID receives one JSON overlay and one matching research dossier. Three four-profile content tasks are independently reviewed before a batch-wide integrity, regression, and release task.

**Tech Stack:** Flutter/Dart, schema-v2 JSON assets, Markdown research dossiers, `SaintProfileValidator`, deterministic queue tooling, service/widget tests, Git worktrees.

---

## Binding acceptance rules

- Read at least three credible actual sources where available, including primary/formal evidence and independent scholarship. Catalog or discovery metadata alone is not content evidence.
- Preserve exact JSON/dossier equality across source ID, tier, author/institution, title, publisher, URL, access date, and reuse basis; locate material claims precisely and wire every source reference.
- Preserve stable IDs and valid celebration aliases; live-check Wikidata mappings. Summaries must be 100–150 words; profiles publish at revision 1 with review date 2026-08-13.
- Distinguish documented, received, traditional, legendary, disputed, and mixed claims. Avoid unsupported precision, popular quotations, copied modern prose, or image reuse without file-level rights.
- Treat colonialism, Indigenous identity, private revelation, antisemitism, anti-Muslim rhetoric, confessional conflict, coercion, illness, disability, medicine, family, sexuality, spiritual authority, miracle claims, martyrdom, violence, child death, monarchy, and nationalism with explicit safeguards.
- Marian feasts or titles that are not particular human biographies must be `observance` profiles with no lifespan/lifeLength/vocation/person simulation. Groups receive no synthetic shared lifespan or person-only QID; biblical figures receive no invented chronology.
- Patronage and symbols require reviewed formal evidence and exact compatible tokens. Calendar title/date/rank and GIRM color evidence must be represented separately unless a source explicitly supplies both.
- Every dossier records rank/color and the exact observed published-validator result.

## Task 1: Indigenous witness, Loreto reception, Roman epigraphy, and Guadalupe

**Profiles:** `juan_diego`, `our_lady_of_loreto`, `damasus_i_pope`, `our_lady_of_guadalupe`

- [ ] Capture exact four-ID RED before edits with `dart run tool/saint_research_queue.dart --ids juan_diego,our_lady_of_loreto,damasus_i_pope,our_lady_of_guadalupe`; expect 144/158 published and four `researched JSON is not indexed` failures.
- [ ] Research Juan Diego through the canonization record, early Guadalupe texts and manuscript chronology, independent Nahua/colonial scholarship, Indigenous agency, name/identity questions, illness/death evidence, and later reception. Treat apparitions as private-revelation tradition rather than public proof; reject colonial conversion triumphalism, racial essentialism, miracle guarantees, coerced belief, and nationalist ownership.
- [ ] Model Our Lady of Loreto as an observance. Research the Holy House tradition, archaeological/building history, medieval translation narratives, liturgical reception, Incarnation theology, pilgrimage, aviation patronage claims, and modern cult. Distinguish Nazareth archaeology from Loreto provenance; reject relic certainty, magical-house claims, unsafe pilgrimage, protection guarantees, and person simulation.
- [ ] Research Damasus I through his surviving epigrams and critical editions, Roman archaeology, episcopal election violence, councils and church politics, Jerome and biblical-text reception, martyr-cult organization, and later papal memory. Do not turn partisan sources into neutral biography, sanitize violence or elite power, project modern papal jurisdiction backward, or use anti-Jewish/anti-heretical rhetoric devotionally.
- [ ] Model Our Lady of Guadalupe as an observance distinct from Juan Diego. Research the `Nican Mopohua` and other early sources with exact manuscript/date/language controls, the tilma and basilica as received material tradition, liturgical/formal patronage evidence, independent colonial and Indigenous scholarship, Mexican/Americas reception, and modern contested uses. Reject apparition or image-as-scientific-proof claims, miracle/cure/pregnancy guarantees, anti-Spanish or anti-Indigenous stereotypes, political ownership, and erasure of Nahua women or communities.
- [ ] Create four JSON/dossier pairs, append exactly four index paths, verify aliases/QIDs/kinds/lifespans/formal arrays/calendar/summaries/parity/refs, run focused profile/service tests, and commit `content: research encounter and Marian memory profiles`.
- [ ] Obtain independent specification and content/source PASSes before Task 2.

## Task 2: Catechesis, university charity, and apostolic witnesses

**Profiles:** `peter_canisius`, `john_of_kanty`, `stephen_first_martyr`, `john_apostle`

- [ ] Capture exact four-ID RED before edits; expect 148/158 after Task 1 and four unindexed-profile failures.
- [ ] Research Peter Canisius through authenticated letters/catechisms and Jesuit archive controls plus independent Reformation-era scholarship on education, preaching, printing, Trent, confessional conflict, illness, death, and Doctor reception. Do not use anti-Protestant or anti-Jewish polemic devotionally, erase women/printers/local collaborators, equate catechesis with coercion, or turn medical/spiritual language into health advice.
- [ ] Research John of Kanty through authenticated university/archival evidence, manuscript and teaching controls, independent late-medieval Kraków scholarship, priestly work, charity traditions, pilgrimage/ascetic reception, death, and cult. Separate documented academic life from later hagiography; reject savior-charity framing, harmful fasting, self-neglect, coerced giving, anti-Jewish assumptions, and Polish nationalist ownership.
- [ ] Model Stephen with the repository’s `biblical` kind and no lifespan/lifeLength. Ground the profile in Acts 6–8 with literary and historical scholarship, distinguishing narrative characterization, speech composition, death, Saul, later relic/cult traditions, and formal feast reception. Explicitly reject anti-Judaism, collective Jewish blame, graphic violence, martyr-seeking, victim-blaming, and claims that Acts supplies a modern trial transcript.
- [ ] Model John as a `biblical` figure with no invented lifespan. Keep John son of Zebedee, the beloved disciple, the Fourth Gospel’s witness/authorial voice, the evangelist, the elder, Patmos seer, and later Ephesian/death traditions critically distinguished. Use canonical texts, early reception, and independent Johannine scholarship; reject anti-Judaism, gendered purity, apostolic superiority, miracle guarantees, and certainty about authorship, celibacy, age, or manner of death.
- [ ] Create four JSON/dossier pairs, append exactly four index paths, verify all formal and source gates, run focused tests, and commit `content: research teaching and apostolic witness profiles`.
- [ ] Obtain independent specification and content/source PASSes before Task 3.

## Task 3: Child victims, contested authority, late-antique papacy, and the Holy Family

**Profiles:** `holy_innocents`, `thomas_becket`, `sylvester_i_pope`, `holy_family`

- [ ] Capture exact four-ID RED before edits; expect 152/158 after Task 2 and four unindexed-profile failures.
- [ ] Model the Holy Innocents as a `group` unless live entity/source review requires an event-centered observance; never reuse a massacre-event QID as a person collective without exact semantic fit. Ground Matthew 2 in literary/historical scholarship, Jeremiah reception, later martyr/cult history, and child-victim remembrance. Do not claim independent historical confirmation, assign invented names/counts/ages, blame Jewish people, graphicize child murder, weaponize abortion/war analogies, or promise protection.
- [ ] Research Thomas Becket through readable primary letters/eyewitness Lives and royal/legal records plus independent scholarship on Henry II, church/state jurisdiction, exile, conflict escalation, murder, miracles/relics, canonization, and later English/European political reception. Preserve contested motives and institutional victims; reject simplistic church-versus-state heroics, monarchy/nationalism, graphic violence, martyr-seeking, and relic/healing certainty.
- [ ] Research Sylvester I through contemporary/near-contemporary council and Roman church evidence, Liber Pontificalis source criticism, archaeology, Constantine-era governance, Nicaea reception, later Donation/dragon/baptism legends, death, and cult. Do not credit him with Constantine’s baptism or the Donation, project later papal power backward, endorse imperial coercion/anti-Judaism, or treat legend as eyewitness biography.
- [ ] Model the Holy Family as a `group` centered on Jesus, Mary, and Joseph, with no shared lifespan/lifeLength/vocation/person-only fields. Research canonical infancy/hidden-life texts, feast development, family theology, migration/refugee reception, work/domestic life, and independent social-historical controls. Reject one-size-fits-all household roles, domestic coercion, child obedience that overrides safeguarding, anti-LGBTQ stigma, fertility pressure, romanticized poverty, anti-migrant use, and treating later domestic scenes as biography.
- [ ] Create four JSON/dossier pairs, append exactly four index paths, verify all gates, run focused tests, and commit `content: research martyr memory and family profiles`.
- [ ] Obtain independent specification and content/source PASSes before Task 4.

## Task 4: Batch-wide integrity and release

- [ ] Run `dart run tool/saint_research_queue.dart --batch 13`; expect 156/158 published and all twelve requested profiles valid.
- [ ] Run `dart run tool/validate_saint_profiles.dart --published-only`; expect 156 researched/validated and zero errors/warnings.
- [ ] Audit every source ledger and material claim, live URL/QID, alias, rank/color, kind, lifespan, summary, formal array, biblical/group/observance omission, safeguard, originality, and media decision.
- [ ] Add real-asset UI regressions for every Batch 13 observance/group/biblical profile, with representative individuals remaining person-centered. Add twelve-profile summary, identity/kind/QID, and rank/color regressions.
- [ ] Run focused tests, `flutter analyze --no-pub`, the full serialized `flutter test --no-pub --concurrency=1`, and range diff/scope/status checks. Correct only confirmed in-scope defects.
- [ ] Commit `content: audit saint research batch 13`, obtain a final independent whole-range release review, and correct/re-review every Critical or Important finding before integration.
