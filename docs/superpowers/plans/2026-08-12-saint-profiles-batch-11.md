# Saint Profiles Batch 11 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade twelve October legacy records into researched schema-v2 profiles with complete dossiers, exact provenance, safe pastoral framing, and correct person/group/observance UI behavior.

**Architecture:** Each stable legacy ID receives one JSON overlay and one matching research dossier. Three four-profile content tasks are independently reviewed before a batch-wide integrity, regression, and release task.

**Tech Stack:** Flutter/Dart, schema-v2 JSON assets, Markdown research dossiers, `SaintProfileValidator`, deterministic queue tooling, service/widget tests, Git worktrees.

---

## Binding acceptance rules

- Read at least three credible actual sources where available, including primary/formal evidence and independent scholarship. Catalog or discovery metadata alone is not content evidence.
- Preserve exact JSON/dossier equality across source ID, tier, author/institution, title, publisher, URL, access date, and reuse basis; locate material claims precisely and wire every source reference.
- Preserve stable IDs and valid celebration aliases; live-check Wikidata mappings. Summaries must be 100–150 words; profiles publish at revision 1 with review date 2026-08-12.
- Distinguish documented, received, traditional, legendary, disputed, and mixed claims. Avoid unsupported precision, popular quotations, copied modern prose, or image reuse without file-level rights.
- Treat colonialism, Indigenous peoples, race, migration, martyrdom, torture, war, nationalism, antisemitism, anti-Muslim rhetoric, illness, disability, medicine, family, sexuality, spiritual authority, private revelation, and sacramentals with explicit safeguards.
- Marian titles or feasts that are not particular human biographies must be `observance` profiles with no lifespan/lifeLength/vocation/person simulation. Groups receive no synthetic shared lifespan or person-only QID.
- Patronage and symbols require reviewed formal evidence and exact compatible tokens. Every dossier records rank/color and the exact observed published-validator result.

## Task 1: Council renewal, Marian reception, early Roman memory, and family agency

**Profiles:** `john_xxiii_pope`, `our_lady_of_aparecida`, `callistus_i_pope`, `hedwig_of_silesia`

- [ ] Capture exact four-ID RED before edits.
- [ ] Research John XXIII through diaries/letters or critical editions, Vatican archives/formal records, Vatican II history, diplomacy, family and illness. Avoid personality-only hagiography, institutional hero myths, or treating every later conciliar result as his personal act.
- [ ] Model Our Lady of Aparecida as an observance through the documented image/find narrative, Brazilian colonial and racial context, shrine/liturgical reception, Marian doctrine, and independent history. Do not simulate Mary’s biography, promise miracles, erase enslaved/Indigenous/Black agency, or turn national devotion into political ownership.
- [ ] Research Callistus through Hippolytan/patristic evidence, Roman archaeology, disputed social origins, penitential policy, schism, martyr reception, and modern scholarship. Source hostility must be explicit; do not repeat slurs, criminalize poverty, or treat later legends as biography.
- [ ] Research Hedwig through documentary/critical medieval evidence, marriage and children, Silesian politics, monastic patronage, widowhood, cult, and German/Polish reception. Preserve women’s agency and reject coercive marriage, unsafe asceticism, dynastic nationalism, or ethnic ownership.
- [ ] Create four JSON/dossier pairs plus index; validate, audit parity/refs/QIDs/calendar/arrays/summaries, run focused tests, and commit `content: research renewal and memory profiles`.
- [ ] Obtain independent specification and content/source PASSes before Task 2.

## Task 2: Devotional authority, canonical witness, colonial martyrdom, and the Cross

**Profiles:** `margaret_mary_alacoque`, `luke_evangelist`, `john_de_brebeuf_and_isaac_jogues`, `paul_of_the_cross`

- [ ] Capture exact four-ID RED before edits.
- [ ] Research Margaret Mary through authenticated letters/autobiography/manuscript controls, Visitation archives, formal Sacred Heart reception, critical scholarship, health and authority history. Private revelation is not public Revelation; reject coercive obedience, self-harm, sexual/body shame, magical promises, and retrospective diagnosis.
- [ ] Ground Luke in canonical texts and early reception while separating Luke the companion, physician, evangelist, Gospel/Acts authorship, Pauline references, mission/death/relic traditions, and iconography. Avoid anti-Judaism and unsupported medical authority.
- [ ] Model Brébeuf, Jogues, and companions according to the celebration’s collective scope. Use letters/Relations with source criticism plus Indigenous and colonial scholarship; name mission-colonial entanglement, Haudenosaunee/Huron-Wendat agency, epidemic/war context, and torture reception without graphic or anti-Indigenous devotion.
- [ ] Research Paul of the Cross through authenticated letters/rule/order archives, independent eighteenth-century history, illness, poverty, preaching, Passion spirituality, and later cult. The Cross never mandates abuse, pain-seeking, medical neglect, or imposed suffering.
- [ ] Create four JSON/dossier pairs plus index; validate, audit parity/refs/QIDs/calendar/arrays/summaries, run focused tests, and commit `content: research witness and compassion profiles`.
- [ ] Obtain independent specification and content/source PASSes before Task 3.

## Task 3: Modern papacy, coercive preaching, missionary governance, and apostolic memory

**Profiles:** `john_paul_ii_pope`, `john_of_capistrano`, `anthony_mary_claret`, `simon_and_jude_apostles`

- [ ] Capture exact four-ID RED before edits.
- [ ] Research John Paul II through primary writings/archives and independent modern history on Poland, Vatican II reception, communism, travel, interreligious relations, sexuality, governance, and the abuse crisis. Sainthood must not erase institutional failures, survivor testimony, or contested decisions.
- [ ] Research John of Capistrano through letters/sermons/legal and critical sources on reform, inquisitorial activity, anti-Jewish preaching, crusade/Belgrade, illness, and cult. Explicitly reject antisemitism, anti-Muslim violence, coercion, triumphalism, and nationalist appropriation.
- [ ] Research Anthony Mary Claret through authenticated autobiography/letters/congregational archives plus independent Spanish/Cuban colonial scholarship, governance, slavery, politics, publishing, illness, and assassination attempts. Do not sanitize colonial or episcopal power, harmful obedience, or medical neglect.
- [ ] Model Simon and Jude as the exact collective apostolic celebration, without synthetic lifespan or person-only QID. Separate canonical apostle lists, name distinctions, letter authorship, mission/martyrdom, relic, and iconographic traditions; avoid desperate-cause magical promises and graphic martyrdom.
- [ ] Create four JSON/dossier pairs plus index; validate, audit parity/refs/QIDs/calendar/arrays/summaries, run focused tests, and commit `content: research authority and apostolic profiles`.
- [ ] Obtain independent specification and content/source PASSes before Task 4.

## Task 4: Batch-wide integrity and release

- [ ] Run `dart run tool/saint_research_queue.dart --batch 11`; expect 132/158 published and all twelve requested profiles valid.
- [ ] Run `dart run tool/validate_saint_profiles.dart --published-only`; expect 132 researched/validated and zero errors/warnings.
- [ ] Audit every source ledger and material claim, live URL/QID, alias, rank/color, kind, lifespan, summary, formal array, observance/group omission, safeguard, originality, and media decision.
- [ ] Add real-asset UI regressions for every Batch 11 observance/group profile, with representative individuals remaining person-centered. Add twelve-profile summary, identity/kind/QID, and rank/color regressions.
- [ ] Run focused tests, `flutter analyze --no-pub`, the full serialized `flutter test --no-pub --concurrency=1`, and range diff/scope/status checks. Correct only confirmed in-scope defects.
- [ ] Commit `content: audit saint research batch 11`, obtain a final independent whole-range release review, and correct/re-review every Critical or Important finding before integration.
