# Saint Profiles Batch 7 Implementation Plan

> **For agentic workers:** Execute one editing task at a time, followed by independent specification and content/source quality reviews.

**Goal:** Upgrade the next twelve late-June and July legacy records into individually researched, spiritually useful schema-v2 profiles with complete dossiers and claim-level provenance.

**Architecture:** Each researched record is a JSON overlay in `assets/data/saints/profiles/` with a matching dossier in `docs/research/saints/dossiers/`. The index loads overlays over the legacy corpus. Validators, research gates, real-asset tests, and batch-wide audits enforce publication quality.

## Binding acceptance rules

- Read at least three credible actual sources where available, combining official/primary Catholic evidence with independent scholarship or recognized historical controls. Snippets, Wikipedia, Wikidata, and legacy prose are discovery aids, not evidence.
- Tier by genre: formal documents, Scripture/primary texts, liturgical texts, decrees, and relevant archives are Tier 1; scholarship/reference works Tier 2; reputable tertiary summaries Tier 3.
- Write original prose; omit unsupported precision and unverified quotations. Mark claims documented, traditional, legendary, disputed, or mixed.
- Keep Christ central and make the guide profile-specific: 3–5 sourced sections where evidence permits, 1–3 virtues or invited dispositions, two practices, two questions, Scripture, and an original prayer.
- Treat sexual violence, child safeguarding, coercion, illness, addiction, fasting, family duties, political power, war, mission, religious conflict, private revelation, and polemical texts safely. Never turn abuse, execution, domination, or preventable suffering into a spiritual good.
- Include patronage or symbols only with reviewed formal evidence, claim-ledger rows, and exact `patronage` or `symbols` compatibility tokens.
- Maintain exact JSON/dossier equality for every represented source field: ID, tier, author/institution, title, publisher, URL, access date, and reuse basis. Include populated claim rows, separate factual/theological reviews, and no image without file-specific licensing.
- Preserve stable IDs and valid celebration IDs; verify every populated Wikidata ID against the live entity and add regression coverage for corrected mappings.
- Use the correct profile kind. Our Lady of Mount Carmel is an event/title-centered liturgical observance: explain what the Church celebrates, Scripture and Carmel, Carmelite history, doctrine, reception, and spiritual practice; omit lifespan and never simulate a saint biography. Groups and biblical or historical people retain person-centered guides.
- `oneMinuteSummary` must be 100–150 words. Editorial state is `published`, revision `1`, review date `2026-08-11`, researcher `Catholic Daily editorial research`, reviewer `Catholic Daily factual and theological review`, warnings empty only after completion.
- Every dossier records the exact published validator command and observed result under `Final validation` and states the celebration rank under calendar scope.

## Task 1: Martyr memory, apostolic encounter, royal peacemaking, and reform

**Profiles:** `first_martyrs_of_rome`, `thomas_apostle`, `elizabeth_of_portugal`, `anthony_zaccaria`

- [ ] Record RED with the exact four-ID research queue before edits.
- [ ] Research the First Martyrs of Rome as a collective memory rooted in Nero’s persecution and early Roman reception. Distinguish Tacitus, later martyrology, unnamed victims, chronology, and legendary detail; reject graphic devotion, collective blame, and anti-Jewish readings.
- [ ] Ground Thomas in the canonical Gospels and early reception while distinguishing the apostle from later Acts, India mission, martyrdom, relic, and architectural traditions. Present questioning as a path toward truthful faith, not a reason to shame doubt or bypass evidence.
- [ ] Research Elizabeth of Portugal through royal records, papal/liturgical reception, and scholarship on marriage, motherhood, dynastic conflict, peacemaking, widowhood, and Poor Clare affiliation. Qualify miracle and family legends; never use her story to require remaining in danger or accepting political/family abuse.
- [ ] Research Anthony Zaccaria through his securely attributed writings, early Barnabite/Angelic histories, reform context, Eucharistic devotion, medical training, and independent scholarship. Separate later miracle/iconographic tradition and make penance, obedience, and reform non-coercive and health-safe.
- [ ] Create four JSON/dossier pairs, index them, validate, review, and commit `content: research witness and reform profiles`.

## Task 2: Safeguarding, political holiness, healthcare, and Marian observance

**Profiles:** `maria_goretti`, `henry_ii_emperor`, `camillus_de_lellis`, `our_lady_of_mount_carmel`

- [ ] Record RED with the exact four-ID queue.
- [ ] Research Maria Goretti with survivor-centered historical and formal sources. State sexual assault and murder without voyeurism; distinguish her actions from later purity rhetoric and the assailant’s subsequent claims. Forgiveness never means blame, impunity, restored access, silence, or refusal of justice, trauma care, and child safeguarding.
- [ ] Research Henry II through charters/chronicles and modern medieval scholarship, preserving Cunigunde’s agency, imperial and ecclesial politics, war, foundations, and canonization reception. Qualify the celibate-marriage and ordeal traditions; do not canonize empire, coercion, involuntary childlessness, or abandonment of marital duties.
- [ ] Research Camillus through early biographies, order archives, healthcare history, and formal reception. Address gambling and illness without retrospective diagnosis or moral shame; present recovery, professional care, safer systems, and service without making prayer replace treatment or healthcare workers ignore limits.
- [ ] Model Our Lady of Mount Carmel as an `observance`, not a biography or independently verified apparition story. Center biblical Carmel, Carmelite identity, Mary’s discipleship, the scapular’s documented history and doctrine, and concrete prayer/service. Reject magical guarantees, fear marketing, compulsory enrollment, and substitution for baptism, sacraments, repentance, medicine, or justice; omit lifespan.
- [ ] Create four JSON/dossier pairs, index them, validate, review, and commit `content: research safeguarding and devotion profiles`.

## Task 3: Sparse martyr evidence, learning and conflict, Gospel witness, and discernment

**Profiles:** `apollinaris_of_ravenna`, `lawrence_of_brindisi`, `mary_magdalene`, `bridget_of_sweden`

- [ ] Record RED with the exact four-ID queue.
- [ ] Research Apollinaris through early cult, archaeology, liturgy, and source-critical study of the later Passio. Keep Ravenna/Classe memory distinct from unsupported apostolic appointment, exact travels, repeated torture, miracle, and martyr details; avoid coercive martyr framing.
- [ ] Research Lawrence of Brindisi through securely attributed works, Capuchin archives, papal reception, and scholarship on languages, preaching, diplomacy, military context, and anti-Jewish polemic. Do not romanticize war preaching, claim miraculous battle causation, or repeat contempt toward Jewish or other living communities.
- [ ] Ground Mary Magdalene in Luke and the four Gospels, especially her healing, discipleship, presence at death/burial, and resurrection witness. Distinguish her from the unnamed sinful woman and other Marys, qualify later conflations and relic traditions, and reject sexualized shame or reduction to a former prostitute.
- [ ] Research Bridget of Sweden as wife, mother, widow, foundress, pilgrim, and visionary through her writings’ transmission, order history, formal discernment, and independent scholarship. Treat revelations as private revelation under ecclesial discernment, not guaranteed predictions; preserve family duties and reject punitive asceticism, political certainty, and unsafe pilgrimage advice.
- [ ] Create four JSON/dossier pairs, index them, validate, review, and commit `content: research witness and discernment profiles`.

## Task 4: Batch-wide integrity and release

- [ ] Run `dart run tool/saint_research_queue.dart --batch 7`; expect 84/158 published and all twelve valid.
- [ ] Run the published validator; expect 84 researched/validated, zero errors/warnings.
- [ ] Audit all twelve profiles/dossiers for originality, live URLs, publication metadata, genre tiers, claim support, exact represented ledgers, Wikidata identity, calendar mappings, kinds, summary length, observance framing, safeguards, and rendering tokens.
- [ ] Add a real-asset test proving the Mount Carmel guide renders as an observance without lifespan or biography headings; add a twelve-profile summary regression and identity/rank regressions for corrected mappings.
- [ ] Run focused profile/calendar/UI tests, `flutter analyze --no-pub`, the full Flutter suite, and range diff checks.
- [ ] Correct confirmed defects with TDD where applicable and commit `content: audit saint research batch 7`.

Every implementation task receives an independent specification review followed by an independent content/source quality review. Critical and Important findings must be corrected and re-reviewed before continuing.
