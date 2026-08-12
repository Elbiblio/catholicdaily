# Saint Profiles Batch 8 Implementation Plan

> **For agentic workers:** Execute one editing task at a time, followed by independent specification and content/source quality reviews.

**Goal:** Upgrade the next twelve late-July and early-August legacy records into individually researched, spiritually useful schema-v2 profiles with complete dossiers and claim-level provenance.

**Architecture:** Each researched record is a JSON overlay in `assets/data/saints/profiles/` with a matching dossier in `docs/research/saints/dossiers/`. The index loads overlays over the legacy corpus. Validators, research gates, real-asset tests, and batch-wide audits enforce publication quality.

## Binding acceptance rules

- Read at least three credible actual sources where available, combining official or primary Catholic evidence with independent scholarship or recognized historical controls. Snippets, Wikipedia, Wikidata, and legacy prose are discovery aids, not evidence.
- Tier by genre: formal documents, Scripture and primary texts, liturgical texts, decrees, and relevant archives are Tier 1; scholarship and critical reference works Tier 2; reputable tertiary summaries Tier 3.
- Write original prose; omit unsupported precision and unverified quotations. Mark claims documented, traditional, legendary, disputed, or mixed.
- Keep Christ central and make each guide profile-specific: 3–5 sourced sections where evidence permits, 1–3 virtues or invited dispositions, two practices, two questions, Scripture, and an original prayer.
- Treat antisemitism and the Shoah, conversion, religious conflict, coercion, martyrdom, illness, disability, miracle and cure claims, fasting, asceticism, mental distress, family duties, grief, political power, poverty, finance, and mission safely. Never turn abuse, execution, domination, genocide, preventable suffering, or medical neglect into a spiritual good.
- Include patronage or symbols only with reviewed formal evidence, claim-ledger rows, and exact `patronage` or `symbols` compatibility tokens.
- Maintain exact JSON/dossier equality for every represented source field: ID, tier, author/institution, title, publisher, URL, access date, and reuse basis. Include populated claim rows, separate factual and theological reviews, and no image without file-specific licensing.
- Preserve stable IDs and valid celebration IDs; verify every populated Wikidata ID against the live entity and add regression coverage for corrected mappings.
- Use the correct profile kind. The Dedication of the Basilica of Saint Mary Major is an event/building-centered liturgical observance: explain what the Church celebrates, the basilica's history and Marian dedication, doctrine, liturgical reception, and spiritual practice; omit lifespan and never simulate a saint biography. Groups, biblical people, and historical people retain person-centered guides.
- `oneMinuteSummary` must be 100–150 words. Editorial state is `published`, revision `1`, review date `2026-08-12`, researcher `Catholic Daily editorial research`, reviewer `Catholic Daily factual and theological review`, and warnings are empty only after completion.
- Every dossier records the exact published validator command and observed result under `Final validation` and states the celebration rank under calendar scope.

## Task 1: Monastic witness, apostolic tradition, preaching, and conciliar conflict

**Profiles:** `sharbel_makhluf`, `james_apostle`, `peter_chrysologus`, `eusebius_of_vercelli`

- [ ] Record RED with the exact four-ID research queue before edits.
- [ ] Research Sharbel through Maronite and Holy See formal reception, monastery records, Lebanese historical context, and critical controls. Distinguish documented monastic life from later miracle and incorruption claims; make solitude, fasting, obedience, illness, and healing claims medically and psychologically safe.
- [ ] Ground James in the canonical Gospels and Acts while separating James son of Zebedee from other Jameses, later Iberian mission, Compostela, relic, military apparition, and pilgrimage traditions. Reject conquest, colonial, anti-Muslim, and danger-seeking uses of the tradition.
- [ ] Research Peter Chrysologus through securely attributed sermons, episcopal and conciliar context, Doctor-of-the-Church reception, and modern scholarship. Control sermon attribution, inherited anti-Jewish rhetoric, imperial-Church power, and miracle legend without sanitizing harmful polemic.
- [ ] Research Eusebius of Vercelli through his letters, Athanasian and conciliar sources, exile history, and modern late-antique scholarship. Preserve the complexity of Nicene conflict, imperial coercion, contested narratives, and communal monastic-clerical reform; do not turn exile or confrontation into a universal leadership method.
- [ ] Create four JSON/dossier pairs, index them, validate, review, and commit `content: research apostolic and teaching profiles`.

## Task 2: Eucharistic devotion, Marian basilica observance, reform, and collective martyr memory

**Profiles:** `peter_julian_eymard`, `dedication_of_basilica_of_saint_mary_major`, `cajetan_of_thiene`, `sixtus_ii_pope`

- [ ] Record RED with the exact four-ID queue.
- [ ] Research Peter Julian Eymard through securely attributed writings, congregation archives, formal reception, and independent historical controls. Present Eucharistic adoration as Christ-centered prayer joined to sacramental life, charity, rest, and justice—not compulsive devotion, spiritual guarantees, or neglect of family, work, illness, or mental health.
- [ ] Model the Dedication of the Basilica of Saint Mary Major as an `observance`, not Mary’s biography or a verified snowfall miracle. Center the basilica, the dedication and calendar history, Marian Christology, worship, art and pilgrimage reception, and service; separate the later snow legend and avoid claims that a building or image guarantees favors.
- [ ] Research Cajetan through his letters, Theatine records, reform context, charitable institutions, the Sack of Rome, and scholarship on early modern finance and poor relief. Separate later miracle stories and do not turn poverty, illness, coercion, or financial risk into devotional prescriptions.
- [ ] Research Sixtus II and companions as the historically correct person/group scope using Cyprian, early calendars, archaeology, and critical study of later Passions. Separate the secure 258 persecution and burial memory from later dialogue, numbers, Lawrence linkage, and execution detail; reject graphic or danger-seeking martyr spirituality.
- [ ] Create four JSON/dossier pairs, index them, validate, review, and commit `content: research devotion and martyr memory profiles`.

## Task 3: Shoah witness, sparse martyr evidence, family vocation, and reconciliation

**Profiles:** `teresa_benedicta_of_the_cross`, `lawrence_of_rome_deacon`, `jane_frances_de_chantal`, `pontian_and_hippolytus`

- [ ] Record RED with the exact four-ID queue.
- [ ] Research Teresa Benedicta through her writings, Carmelite and Church archives, Shoah records, and independent Holocaust scholarship. Preserve Edith Stein’s Jewish identity and family agency; never frame baptism as erasing Jewishness, blame Jewish victims, appropriate the Shoah for conversion, or imply canonization explains or redeems genocide. Distinguish formal martyr reception from historical disputes and avoid fabricated last words.
- [ ] Research Lawrence of Rome from early Roman cult, near-contemporary reception, archaeology, and critical analysis of the later Passion. Keep diaconal identity and martyr memory distinct from legendary gridiron, treasure-distribution dialogue, census, conversion, and relic narratives; use service of the poor without romanticizing torture.
- [ ] Research Jane Frances de Chantal through her letters, Visitation archives, Francis de Sales correspondence, and modern scholarship on marriage, widowhood, children, grief, spiritual direction, and women’s religious leadership. Safeguard against abandonment of dependants, coercive obedience, suppression of grief, self-harm, or unsafe asceticism.
- [ ] Research Pontian and Hippolytus as a reconciled pair with distinct identities and contested Hippolytan corpus. Use early calendars, inscriptions, primary Church histories, and current scholarship; distinguish schism, exile, mines, reconciliation, martyr title, and later legends without making coercion or forced unity exemplary.
- [ ] Create four JSON/dossier pairs, index them, validate, review, and commit `content: research witness and reconciliation profiles`.

## Task 4: Batch-wide integrity and release

- [ ] Run `dart run tool/saint_research_queue.dart --batch 8`; expect 96/158 published and all twelve valid.
- [ ] Run the published validator; expect 96 researched/validated, zero errors/warnings.
- [ ] Audit all twelve profiles and dossiers for originality, live URLs, publication metadata, genre tiers, claim support, exact represented ledgers, Wikidata identity, calendar mappings, kinds, summary length, observance framing, safeguards, and rendering tokens.
- [ ] Add a real-asset test proving the Saint Mary Major guide renders as an observance without lifespan or biography headings; add a twelve-profile summary regression and identity/rank regressions for corrected mappings.
- [ ] Run focused profile/calendar/UI tests, `flutter analyze --no-pub`, the full serialized Flutter suite, and range diff checks.
- [ ] Correct confirmed defects with TDD where applicable and commit `content: audit saint research batch 8`.

Every implementation task receives an independent specification review followed by an independent content/source quality review. Critical and Important findings must be corrected and re-reviewed before continuing.
