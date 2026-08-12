# Saint Profiles Batch 9 Implementation Plan

> **For agentic workers:** Execute one editing task at a time, followed by independent specification and content/source quality reviews.

**Goal:** Upgrade twelve August and early-September legacy records into researched schema-v2 profiles with complete dossiers and claim-level provenance.

## Binding acceptance rules

- Read at least three credible actual sources where available, combining primary/formal Catholic evidence with independent scholarship or recognized historical controls. Discovery pages are not evidence.
- Tier by genre, write original prose, omit unsupported precision and quotations, and label documented, traditional, legendary, disputed, or mixed claims.
- Maintain exact JSON/dossier equality for source ID, tier, author/institution, title, publisher, URL, access date, and reuse basis. Every material claim and formal array needs represented support.
- Preserve stable IDs and valid celebration IDs; live-check every stored Wikidata entity. Keep summaries at 100–150 words and editorial metadata published/revision 1/reviewed 2026-08-12.
- Treat political power, colonialism, enslavement, race, poverty, illness, education, family duties, martyrdom, violence, private tradition, infertility, pregnancy, and Marian devotion safely. Never spiritualize abuse, domination, genocide, preventable suffering, or medical neglect.
- The Assumption, Queenship of Mary, Passion of John the Baptist, Nativity of Mary, and Holy Name of Mary are `observance` profiles. Omit lifespan/lifeLength and center what the Church celebrates, Scripture and doctrine, liturgical history, reception, and concrete practice—not a simulated biography.
- Patronage/symbols require reviewed formal evidence and exact compatibility tokens. No image without file-specific licensing. Every dossier records calendar rank and the exact observed published-validator result.

## Task 1: Marian mysteries, royal power, and missionary renewal

**Profiles:** `the_assumption_of_the_blessed_virgin_mary`, `stephen_of_hungary`, `john_eudes`, `queenship_of_blessed_virgin_mary`

- [ ] Capture exact RED before edits.
- [ ] Model the Assumption as an observance: Scripture and tradition, dogmatic definition, Eastern/Western reception, bodily hope and resurrection, without invented death details, medical claims, or treating art as proof.
- [ ] Research Stephen through charters, political history, Christianization, war, succession, family, law, and canonization reception; do not canonize monarchy, coercion, or nationalist appropriation.
- [ ] Research John Eudes through securely attributed writings, congregation archives, reform and formation history, and devotion to Jesus and Mary; control attribution, severe asceticism, authority, and later devotional claims.
- [ ] Model the Queenship of Mary as an observance rooted in Christ’s kingship, Scripture, teaching, and liturgical history; reject domination, political triumphalism, magical intercession, and biography simulation.
- [ ] Create four JSON/dossier pairs, index, validate, review, and commit `content: research hope and renewal profiles`.

## Task 2: Apostolic witness, education, and political responsibility

**Profiles:** `rose_of_lima`, `bartholomew_apostle`, `joseph_of_calasanz`, `louis_ix_of_france`

- [ ] Capture exact RED before edits.
- [ ] Research Rose in colonial Peru with family, labor, Dominican reception, illness and source-critical ascetic/hagiographic controls. Reject self-harm imitation, racialized colonial erasure, and guaranteed miracles.
- [ ] Ground Bartholomew in the apostle lists and early reception while distinguishing him from Nathanael and later India/Armenia, martyrdom, relic, and skinning traditions; avoid graphic devotion and nationalist ownership.
- [ ] Research Joseph Calasanz through letters/order archives and scholarship on free education, poverty, institutional conflict, abuse safeguarding, governance, and rehabilitation; never excuse abuse or coercive schooling.
- [ ] Research Louis IX through royal records and modern scholarship on governance, family, justice, crusades, Jewish policy, captivity, and canonization. State violence, coercion, antisemitism, and political harm without triumphalism.
- [ ] Create four JSON/dossier pairs, index, validate, review, and commit `content: research learning and responsibility profiles`.

## Task 3: Prophetic witness, Marian reception, and colonial mission

**Profiles:** `passion_of_john_the_baptist`, `nativity_of_blessed_virgin_mary`, `peter_claver`, `most_holy_name_of_mary`

- [ ] Capture exact RED before edits.
- [ ] Model John the Baptist’s Passion as an observance centered on the Gospel event, truth, conscience, political violence, martyr memory, and safe witness; no lifespan, graphic spectacle, or danger-seeking.
- [ ] Model Mary’s Nativity as an observance: later tradition, liturgical development, doctrine, Israel and salvation history, family and human dignity; no invented childhood biography, infertility blame, or promised pregnancy.
- [ ] Research Peter Claver through his writings, Jesuit archives, Cartagena/slavery scholarship, African agency, colonial Church complicity, healthcare and formal reception. Do not sanitize slavery, paternalism, forced baptism, or racial harm.
- [ ] Model the Holy Name of Mary as an observance through Scripture, naming, liturgical history, doctrine, prayer, and reception. Separate later military/political associations and reject magical invocation or anti-Muslim triumphalism.
- [ ] Create four JSON/dossier pairs, index, validate, review, and commit `content: research witness and dignity profiles`.

## Task 4: Batch-wide integrity and release

- [ ] Run `dart run tool/saint_research_queue.dart --batch 9`; expect 108/158 published and all twelve valid.
- [ ] Run the published validator; expect 108 researched/validated and zero errors/warnings.
- [ ] Audit all source ledgers, claims, live URLs/QIDs, mappings, ranks, kinds, summary length, observance framing, safeguards, arrays, originality, and media decisions.
- [ ] Add real-asset UI tests for all five observance profiles, a twelve-summary regression, and corrected identity/rank regressions.
- [ ] Run focused tests, `flutter analyze --no-pub`, the full serialized suite, and range diff checks; correct confirmed defects and commit `content: audit saint research batch 9`.

Every implementation task receives independent specification and content/source reviews. Critical and Important findings must be corrected and re-reviewed before continuing.
