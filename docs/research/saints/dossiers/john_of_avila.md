# Saint John of Ávila, Priest and Doctor of the Church

## Identity resolution

- Stable ID: `john_of_avila`
- Profile kind: individual
- Celebration IDs: `john_of_avila`, `saint_john_of_vila_priest_and_doctor_of_the_church`
- Canonical name and aliases: Saint John of Ávila; John of Avila; Juan de Ávila; Master Ávila
- Feast date and calendar scope: May 10; optional memorial
- Lifespan and life length: c. 1500–1569; about 69 years. The formal Doctor letter gives January 6 in either 1499 or 1500, so the profile does not assert one exact birth year.
- Identity conflicts resolved: This is the Spanish diocesan priest and Doctor of the Church, not John of the Cross or John of God. Only the formally documented patronage of Spain's diocesan clergy is retained; generic theologian, teacher, and preacher associations are not treated as patronage.

## Exact RED baseline

Before the Task 1 overlays were indexed, the exact four-ID queue reported `48/158 published` and failed `john_of_avila`, `nereus_and_achilleus`, `pancras_of_rome`, and `our_lady_of_fatima` because each researched JSON was not indexed.

## Source ledger

| ID | Tier | Author/institution | Title | Publisher | URL | Accessed | Reuse basis |
|---|---:|---|---|---|---|---|---|
| avila-doctor-letter | 1 | Pope Benedict XVI | Apostolic Letter Proclaiming Saint John of Avila, Diocesan Priest, a Doctor of the Universal Church | Holy See | https://www.vatican.va/content/benedict-xvi/en/apost_letters/documents/hf_ben-xvi_apl_20121007_giovanni-avila.html | 2026-08-11 | Formal declaration and historical-theological synthesis for disputed birth dating, education, preaching, imprisonment and acquittal, illness, works, Doctor recognition, canonization, and formal patronage |
| avila-audi-filia | 1 | Saint John of Ávila | Avisos y reglas cristianas para los que desean servir a Dios... Audi, filia | Biblioteca Virtual Miguel de Cervantes | https://www.cervantesvirtual.com/obra-visor/avisos-y-reglas-cristianas-compuestas-sobre-aquel-verso-de-david-audi-filia--0/html/fef5d03e-82b1-11df-acc7-002185ce6064_1.html | 2026-08-11 | Stable full-text presentation of John's primary Spanish work, used for hearing God's word, contemplation of Christ, humility, and discernment without reproducing its wording |
| avila-nce | 2 | J. C. Willke, New Catholic Encyclopedia | John of Avila, St. | Encyclopedia.com | https://www.encyclopedia.com/religion/encyclopedias-almanacs-transcripts-and-maps/john-avila-st | 2026-08-11 | Specialist reference control for chronology, Inquisition proceedings, Andalusian preaching, Baeza, formation, writings, and feast |
| avila-usccb-liturgy | 1 | United States Conference of Catholic Bishops | Optional Memorial of John of Avila, Priest and Doctor of the Church | United States Conference of Catholic Bishops | https://bible.usccb.org/bible/readings/0510b-memorial-Johnofavila | 2026-08-11 | Official liturgical source for May 10, optional-memorial rank, title, and assigned Scripture |

## Claim ledger

| Profile field | Claim or editorial conclusion | Source IDs | Certainty | Reconciliation note |
|---|---|---|---|---|
| identity, lifespan | John was born on January 6 in 1499 or 1500 and died May 10, 1569. | avila-doctor-letter; avila-nce | High with birth-year conflict | `c. 1500–1569` preserves the formal source's alternatives and avoids false precision. |
| ministry | Ordained in 1526, he preached in Andalusia, directed people spiritually, formed clergy, supported colleges and Baeza, and wrote sermons, letters, reform proposals, and `Audi, filia`. | avila-doctor-letter; avila-audi-filia; avila-nce | High | Influence on reform is described without making him the single cause of Trent or later seminaries. |
| Inquisition proceedings | He was denounced to the Spanish Inquisition in 1531, imprisoned in 1532, and acquitted in 1533. | avila-doctor-letter; avila-nce | High with source chronology reconciled | The Vatican synthesis compresses the sequence; the scholarly control distinguishes denunciation from imprisonment. Acquittal does not make coercive detention good or every later opinion infallible. |
| illness | Ill health curtailed travel from 1554 while writing and counsel continued at Montilla. | avila-doctor-letter | High | Adapted service is not a rejection of medical care or bodily limits. |
| patronage | Pius XII declared him patron of Spain's diocesan clergy in 1946. | avila-doctor-letter | High formal evidence | The exact `patronage` token supports only `diocesan clergy of Spain`. |
| feast, Scripture | May 10 is his optional memorial, with Acts 13 and Matthew 5 readings. | avila-usccb-liturgy | High formal liturgical evidence | The Gospel grounds witness in deeds that glorify the Father. |
| historicalCertainty | Core life, writings, recognition, and formal patronage are documented; one exact birth year is unresolved. | avila-doctor-letter; avila-nce | High overall | The profile uses `documented` while stating the date conflict explicitly. |

## Safeguards and rejected claims

- Imprisonment is not romanticized as a useful spiritual technique or an accountable model merely because John continued his work.
- Illness is not presented as failure, weak faith, or a reason to refuse qualified care.
- The profile rejects ownership language claiming that John single-handedly “converted” other saints or caused every later reform.
- Generic legacy patronage and popular book, pen, or crucifix imagery are omitted without formal evidence.
- Teaching practices require study, verification, listener feedback, and accountability rather than authority by charisma.

## Copyright and media decision

The formal letter, reference work, liturgical page, and Spanish primary text are synthesized in original prose. No passage from the primary work or liturgical collect is reproduced. No image is included because file-specific reusable licensing was not established.

## Content review

The factual pass checked the birth-year conflict, education, ordination, Andalusian ministry, Inquisition imprisonment and acquittal, colleges and Baeza, major works, illness, death, canonization, Doctor recognition, feast, and formal patronage. Unsupported causation, generic patronage, symbols, and anecdotal precision were removed.

## Theological review

Christ's grace, Scripture, prayer, neighbor-love, and service govern the guide. Teaching remains accountable to truth and those affected. Coercion is not sanctified, correction does not erase dignity, and prudent health limits can reshape ministry without erasing vocation.

## Final validation

- Researcher: Catholic Daily editorial research
- Reviewer: Catholic Daily factual and theological review
- Review date: 2026-08-11
- Revision: 1
- Status: published
- Command: `dart run tool/validate_saint_profiles.dart --published-only`
- Result: PASS — 158 total, 158 legacy, 52 researched, 52 validated, 0 errors, 0 warnings
- Warnings: none
