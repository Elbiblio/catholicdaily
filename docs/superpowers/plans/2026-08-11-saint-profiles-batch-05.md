# Saint Profiles Batch 5 Implementation Plan

> **For agentic workers:** Use subagent-driven development one editing task at a time, followed by independent specification and content/source quality reviews.

**Goal:** Upgrade the next twelve May legacy records into individually researched, spiritually useful schema-v2 profiles with complete dossiers and claim-level provenance.

**Architecture:** Each researched record is a JSON overlay in `assets/data/saints/profiles/` with a matching dossier in `docs/research/saints/dossiers/`. The index loads overlays over the legacy corpus. Validators and the research gate enforce published data and exact ledgers.

## Binding acceptance rules

- Read at least three credible actual sources where available, combining official/primary Catholic evidence with independent scholarship or recognized historical controls. Snippets, Wikipedia, Wikidata, and legacy prose are not evidence.
- Tier by genre: formal documents, Scripture/primary texts, liturgical texts, decrees, and relevant archives are Tier 1; scholarship/reference works Tier 2; reputable tertiary summaries Tier 3.
- Write original prose; omit unsupported precision and unverified quotations. Mark claims documented, traditional, legendary, disputed, or mixed.
- Keep Christ central and make the life guide profile-specific: 3–5 sourced sections where evidence permits, 1–3 virtues/dispositions, two practices, two questions, Scripture, and an original prayer.
- Treat violence, coercion, illness, fasting, family duties, mission, power, religious conflict, and institutional authority safely. Never turn abuse, execution, domination, or preventable suffering into a spiritual good.
- Include patronage/symbols only with reviewed formal evidence, claim-ledger rows, and exact `patronage`/`symbols` compatibility tokens.
- Maintain exact JSON/dossier source-ID and tier equality, populated claim rows, separate factual/theological reviews, and no image without file-specific licensing.
- Preserve stable IDs and valid celebration IDs; use the correct profile kind. For a feast or memorial not centered on a particular person, use an observance-centered structure: explain what the Church celebrates, its doctrine/Scripture/liturgical history and spiritual practice; omit lifespan and never simulate a saint biography.
- `oneMinuteSummary` must be 100–150 words. Editorial state is `published`, revision `1`, review date `2026-08-11`, researcher `Catholic Daily editorial research`, reviewer `Catholic Daily factual and theological review`, warnings empty only after completion.
- Every dossier records the exact published validator command and observed result under `Final validation`.

## Task 1: Teaching, martyr memory, youth, and the Fatima observance

**Profiles:** `john_of_avila`, `nereus_and_achilleus`, `pancras_of_rome`, `our_lady_of_fatima`

- [ ] Record RED with the exact four-ID research queue before edits.
- [ ] Research John of Avila through his writings, formal Doctor recognition, and scholarship; control chronology, reform influence, illness, and disputed popular claims.
- [ ] Treat Nereus and Achilleus as a joint martyr memory with sparse evidence; distinguish Damasus and early cult evidence from later legendary Acts and invented military detail.
- [ ] Treat Pancras with the same historical restraint; do not turn youth, martyrdom, or legendary details into pressure on children or unsafe heroics.
- [ ] Model Our Lady of Fatima as an `observance`, not a Marian biography: omit lifespan, distinguish reported 1917 apparitions, ecclesial discernment, later interpretation, secrets, solar-event testimony, devotion, and contested claims. Center conversion to Christ, prayer, peace, reparation without scrupulosity, and responsible action rather than prediction or fear.
- [ ] Create four JSON/dossier pairs, index them, validate, review, and commit `content: research teaching and memorial profiles`.

## Task 2: Apostolic calling, papal witness, preaching, and persecution

**Profiles:** `matthias_apostle`, `john_i_pope`, `bernardine_of_siena`, `christopher_magallanes`

- [ ] Record RED with the exact four-ID queue.
- [ ] Ground Matthias in Acts and early reception while separating selection into the Twelve from later travel/death traditions.
- [ ] Control John I's diplomacy, imprisonment, death, and Gothic/Roman conflict without inventing motive or glorifying mistreatment.
- [ ] Research Bernardine's preaching, reform, Holy Name devotion, economic teaching, and anti-Jewish or coercive contexts honestly; do not reproduce contemptuous rhetoric.
- [ ] Research Christopher Magallanes and companions using formal Mexican/Church evidence plus historical controls; distinguish individual cases, Cristero conflict, state violence, armed resistance, and martyr recognition without romanticizing war.
- [ ] Create four pairs, index, validate, review, and commit `content: research apostolic and witness profiles`.

## Task 3: Vocation, learning, reform conflict, and mystical prayer

**Profiles:** `rita_of_cascia`, `bede_the_venerable`, `gregory_vii_pope`, `mary_magdalene_de_pazzi`

- [ ] Record RED with the exact four-ID queue.
- [ ] Research Rita with careful controls for marriage, violence, widowhood, family, religious vocation, wounds, and later miracle traditions; never normalize unsafe marriage or claim prayer guarantees impossible outcomes.
- [ ] Research Bede through primary works and scholarship; distinguish secure monastic scholarship from later legends and use learning in service of prayer, truth, and community.
- [ ] Present Gregory VII's reform, investiture conflict, excommunications, politics, exile, and legacy without reducing complex institutions to a saint-versus-villain story or canonizing every policy.
- [ ] Research Mary Magdalene de Pazzi through Carmelite primary/order evidence and scholarship; distinguish documented life/writings from visionary claims and make fasting, illness, obedience, and mystical language safe for modern readers.
- [ ] Create four pairs, index, validate, review, and commit `content: research vocation and reform profiles`.

## Task 4: Batch-wide integrity and release

- [ ] Run `dart run tool/saint_research_queue.dart --batch 5`; expect 60/158 published and all twelve valid.
- [ ] Run the published validator; expect 60 researched/validated, zero errors/warnings.
- [ ] Audit all twelve profiles/dossiers for originality, URLs, publication metadata, genre tiers, claim support, exact ledgers, calendar mappings, kinds, summary length, observance framing, safeguards, and rendering tokens.
- [ ] Run focused profile/calendar/UI tests, `flutter analyze --no-pub`, the full Flutter suite, and diff checks.
- [ ] Correct confirmed defects with TDD where applicable and commit `content: audit saint research batch 5`.

Every implementation task receives an independent specification review followed by an independent quality review. Critical and Important findings must be corrected and re-reviewed before continuing.
