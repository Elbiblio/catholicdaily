# Saint Profiles Batch 6 Implementation Plan

> **For agentic workers:** Execute one editing task at a time, followed by independent specification and content/source quality reviews.

**Goal:** Upgrade the next twelve late-May and June legacy records into individually researched, spiritually useful schema-v2 profiles with complete dossiers and claim-level provenance.

**Architecture:** Each researched record is a JSON overlay in `assets/data/saints/profiles/` with a matching dossier in `docs/research/saints/dossiers/`. The index loads overlays over the legacy corpus. Validators, research gates, real-asset tests, and batch-wide audits enforce publication quality.

## Binding acceptance rules

- Read at least three credible actual sources where available, combining official/primary Catholic evidence with independent scholarship or recognized historical controls. Snippets, Wikipedia, Wikidata, and legacy prose are discovery aids, not evidence.
- Tier by genre: formal documents, Scripture/primary texts, liturgical texts, decrees, and relevant archives are Tier 1; scholarship/reference works Tier 2; reputable tertiary summaries Tier 3.
- Write original prose; omit unsupported precision and unverified quotations. Mark claims documented, traditional, legendary, disputed, or mixed.
- Keep Christ central and make the life guide profile-specific: 3–5 sourced sections where evidence permits, 1–3 virtues or invited dispositions, two practices, two questions, Scripture, and an original prayer.
- Treat violence, coercion, illness, fasting, family duties, mission, power, religious conflict, institutional authority, and polemical texts safely. Never turn abuse, execution, domination, or preventable suffering into a spiritual good.
- Include patronage or symbols only with reviewed formal evidence, claim-ledger rows, and exact `patronage` or `symbols` compatibility tokens.
- Maintain exact JSON/dossier equality for every represented source field: ID, tier, author/institution, title, publisher, URL, access date, and reuse basis. Include populated claim rows, separate factual/theological reviews, and no image without file-specific licensing.
- Preserve stable IDs and valid celebration IDs; verify every populated Wikidata ID against the live entity and add regression coverage for corrected mappings.
- Use the correct profile kind. The Visitation and the Nativity of Saint John the Baptist are event-centered liturgical observances: explain what the Church celebrates, Scripture, doctrine, liturgical reception, and spiritual practice; omit lifespan and never simulate a saint biography. Person and group celebrations retain person-centered guides.
- `oneMinuteSummary` must be 100–150 words. Editorial state is `published`, revision `1`, review date `2026-08-11`, researcher `Catholic Daily editorial research`, reviewer `Catholic Daily factual and theological review`, warnings empty only after completion.
- Every dossier records the exact published validator command and observed result under `Final validation` and states the celebration rank under calendar scope.

## Task 1: Mission, conciliar reception, biblical encounter, and martyr memory

**Profiles:** `augustine_of_canterbury`, `paul_vi_pope`, `visitation_of_mary`, `marcellinus_and_peter`

- [ ] Record RED with the exact four-ID research queue before edits.
- [ ] Research Augustine through Bede and current scholarship; retain Kentish and papal mission context, Æthelberht and Bertha's agency, Gregory's adaptive counsel, later English reception, and colonial/forced-conversion safeguards. Do not make one missionary the sole founder of English Christianity.
- [ ] Research Paul VI through primary papal texts, Vatican II implementation, peace and social teaching, liturgical reform, contested reception, and independent historical controls. Distinguish canonized witness from universal approval of every prudential decision.
- [ ] Model the Visitation as an `observance`, not a biography of Mary or Elizabeth. Center Luke 1, Christ's presence, Spirit-filled recognition, the Magnificat, mutual care, liturgical history, pregnancy and family safety, and concrete solidarity without romanticizing hardship.
- [ ] Treat Marcellinus and Peter as a joint martyr memory with sparse early evidence; distinguish Damasus and early cult testimony from later execution dialogue, conversion, burial, and miracle embellishment. Avoid graphic or coercive martyr framing.
- [ ] Create four JSON/dossier pairs, index them, validate, review, and commit `content: research mission and encounter profiles`.

## Task 2: Reform, Syriac theology, apostolic encouragement, and monastic solitude

**Profiles:** `norbert_of_xanten`, `ephrem_the_syrian`, `saint_barnabas_apostle`, `romuald_of_ravenna`

- [ ] Record RED with the exact four-ID queue.
- [ ] Research Norbert's conversion tradition, Premonstratensian foundation, Eucharistic and clerical reform, episcopal politics, and conflict using order sources plus independent scholarship. Do not convert contested anti-heresy or political activity into coercive spiritual advice.
- [ ] Research Ephrem through securely attributed Syriac works, liturgical reception, current scholarship, Nisibis/Edessa context, poetry and biblical theology, and attribution controls. Do not repeat later ascetic or anti-group polemics as timeless guidance.
- [ ] Ground Barnabas in Acts and Pauline evidence while distinguishing the biblical Joseph/Barnabas from later Cyprus, martyrdom, relic, and authorship traditions. Emphasize encouragement, mediation, mission partnership, conflict repair, and accountable discernment rather than lone heroism.
- [ ] Research Romuald using the earliest Vita and modern monastic scholarship; distinguish secure reform activity from sensational family, penance, vision, miracle, and incorruption narratives. Make solitude accountable, safe, and compatible with community and mental/physical care.
- [ ] Create four pairs, index, validate, review, and commit `content: research reform and encouragement profiles`.

## Task 3: Conscience, episcopal service, prophetic birth, and doctrinal conflict

**Profiles:** `john_fisher_and_thomas_more`, `paulinus_of_nola`, `the_nativity_of_saint_john_the_baptist`, `cyril_of_alexandria`

- [ ] Record RED with the exact four-ID queue.
- [ ] Treat Fisher and More as a two-person group with distinct biographies, offices, legal cases, writings, family responsibilities, and deaths. Explain conscience, royal supremacy, due process, and Tudor coercion without equating holiness with seeking execution or erasing More's own coercive actions and contested legacy.
- [ ] Research Paulinus through his letters and poems plus scholarship; distinguish documented senatorial renunciation, marriage and shared family grief, Nola/Felix devotion, episcopal service, wealth use, and contested captivity or ransom legends. Do not prescribe abandonment of dependants or romantic poverty.
- [ ] Model the Nativity of Saint John the Baptist as an `observance`, not a cradle-to-death saint biography. Center Luke 1, God's fidelity, Zechariah and Elizabeth, John's prophetic vocation as the feast reveals it, the Benedictus, liturgical dating, dignity of children, and family/community welcome; omit lifespan.
- [ ] Research Cyril through primary conciliar and theological texts plus modern scholarship; explain Nestorian controversy, Ephesus, Christological achievement, political procedure, coercion, anti-Jewish violence/expulsion context, and source disputes without canonizing every tactic or repeating contempt.
- [ ] Create four pairs, index, validate, review, and commit `content: research conscience and doctrine profiles`.

## Task 4: Batch-wide integrity and release

- [ ] Run `dart run tool/saint_research_queue.dart --batch 6`; expect 72/158 published and all twelve valid.
- [ ] Run the published validator; expect 72 researched/validated, zero errors/warnings.
- [ ] Audit all twelve profiles/dossiers for originality, live URLs, publication metadata, genre tiers, claim support, exact represented ledgers, Wikidata identity, calendar mappings, kinds, summary length, observance framing, safeguards, and rendering tokens.
- [ ] Add real-asset tests proving the Visitation and Nativity guides render as observances without lifespan or biography headings; add a twelve-profile summary regression.
- [ ] Run focused profile/calendar/UI tests, `flutter analyze --no-pub`, the full Flutter suite, and range diff checks.
- [ ] Correct confirmed defects with TDD where applicable and commit `content: audit saint research batch 6`.

Every implementation task receives an independent specification review followed by an independent content/source quality review. Critical and Important findings must be corrected and re-reviewed before continuing.
