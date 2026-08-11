# Saint Matthias, Apostle

## Identity resolution

- Stable ID: `matthias_apostle`
- Profile kind: biblical
- Celebration IDs: `matthias_apostle`; `saint_matthias_apostle`
- Canonical name and aliases: Saint Matthias, Apostle; Matthias the Apostle
- Feast date and calendar scope: May 14, feast, red. This is the proper date, not a promise of universal occurrence: a higher celebration can take precedence; the Ascension does so in Nigeria in 2026.
- Lifespan and life length: omitted. Acts supplies no birth, age, death date, or reliable chronology from which either can be calculated.
- Identity conflicts resolved: the Matthias chosen in Acts is secure. Eusebius's tradition that he belonged to the seventy is reported as reception, while mutually incompatible travel, death, and relic traditions are excluded from biography.

## Exact RED baseline

Before any Task 2 edit, `dart run tool/saint_research_queue.dart --ids matthias_apostle,john_i_pope,bernardine_of_siena,christopher_magallanes` exited 1. It reported `Saint research queue: 52/158 published, 0 in progress, 106 remaining.` Each of the four IDs failed because `researched JSON is not indexed`.

## Source ledger

| ID | Tier | Author/institution | Title | Publisher | URL | Accessed | Reuse basis |
|---|---:|---|---|---|---|---|---|
| matthias-acts-usccb | 1 | United States Conference of Catholic Bishops | Acts of the Apostles, Chapter 1 | United States Conference of Catholic Bishops | https://bible.usccb.org/bible/acts/1 | 2026-08-11 | Canonical text for the vacancy, qualifications, prayer, lots, election, and resurrection witness |
| matthias-benedict-audience | 1 | Pope Benedict XVI | Judas Iscariot and Matthias | Holy See | https://www.vatican.va/content/benedict-xvi/en/audiences/2006/documents/hf_ben-xvi_aud_20061018.html | 2026-08-11 | Formal catechesis for ecclesial reception and the acknowledged lack of reliable later biography |
| matthias-eusebius-history | 1 | Eusebius of Caesarea | Ecclesiastical History, Book I, Chapter 12 | Bibliothek der Kirchenvaeter, University of Fribourg | https://bkv.unifr.ch/en/works/cpg-3495/compare/the-church-history-of-eusebius/14/kirchengeschichte-bkv-2 | 2026-08-11 | Early primary reception for the reported tradition that Matthias belonged to the seventy, not proof of later career |
| matthias-nce | 2 | New Catholic Encyclopedia | Matthias, Apostle, St. | Encyclopedia.com | https://www.encyclopedia.com/religion/encyclopedias-almanacs-transcripts-and-maps/matthias-apostle-st | 2026-08-11 | Historical control distinguishing Acts from legendary later careers and explaining restoration of the Twelve |
| matthias-cei-liturgy | 1 | Italian Episcopal Conference | Liturgy of the Day: Saint Matthias, Apostle | Chiesa Cattolica Italiana | https://www.chiesacattolica.it/liturgia-del-giorno/?data-liturgia=20260514 | 2026-08-11 | Official date, feast rank, red color, and readings, subject to local precedence |

## Claim ledger

| Profile field | Claim or editorial conclusion | Source IDs | Certainty | Reconciliation note |
|---|---|---|---|---|
| profileKind, identity | Matthias is the biblical disciple chosen and counted with the eleven in Acts 1. | matthias-acts-usccb; matthias-benedict-audience | High | `biblical` identifies the documentary center without implying that every later tradition is Scripture. |
| apostolic qualification | A candidate had accompanied the disciples from John's baptism through the Ascension and could witness to the Resurrection. | matthias-acts-usccb | High | The requirement is sustained presence and witness, not a later heroic itinerary. |
| election | The community proposed two candidates, prayed, cast lots, and received Matthias. | matthias-acts-usccb | High | The profile does not turn lots into a general method that bypasses transparent responsibility. |
| the Twelve | Restoring the Twelve carries symbolic and missionary continuity. | matthias-nce; matthias-acts-usccb | High interpretive conclusion | The vacancy concerns ecclesial mission, not replacing Judas's personality. |
| the seventy | Eusebius reports a tradition that Matthias was among the seventy. | matthias-eusebius-history | Low as independently verified biography | It remains reception evidence rather than merged biblical fact. |
| later ministry and death | Scripture is silent; later travel, martyrdom, burial, and relic accounts conflict. | matthias-benedict-audience; matthias-nce | Low for specific later stories | No single itinerary, death, or relic claim is asserted. |
| feast | May 14 is a red feast on its proper calendar, with possible local displacement by a higher celebration. | matthias-cei-liturgy | High liturgical evidence | Nigeria's 2026 Ascension collision is named to prevent a false universal calendar claim. |
| patronage, symbols | Both arrays remain empty. | matthias-acts-usccb; matthias-cei-liturgy | High editorial conclusion | Popular axes, books, lots, carpenters, and locations are not entered as reviewed formal compatibility tokens. |
| historicalCertainty | Election is canonical; subsequent biography is sparse and tradition-dependent. | matthias-acts-usccb; matthias-eusebius-history; matthias-nce | Mixed | The profile locates the exact boundary between text and reception. |

## Biblical and tradition safeguard

- Acts 1 is the secure narrative core. Eusebius is labeled early reception, not independent verification of Luke.
- No contradictory Judea, Ethiopia, Colchis, crucifixion, stoning, beheading, or relic account is selected to manufacture a continuous biography.
- Casting lots is described within Acts; it is not recommended as a substitute for qualifications, consultation, safeguarding, or accountable appointments.
- Judas is not used as a pretext for contempt, and Matthias is not depicted as gaining fame from another person's ruin.

## Copyright and media decision

All sources are paraphrased. No biblical translation, papal address, encyclopedia entry, or ancient translation is reproduced beyond brief identifying phrases. No image is included without file-specific license review.

## Content review

The factual pass checked identity, candidate requirements, communal prayer, election, the symbolic Twelve, early reception, feast rank and color, local precedence, and the evidence boundary after Acts. Unsupported lifespan, patronage, symbols, journeys, death, and relic certainty were removed.

## Theological review

The profile treats apostolic office as service to resurrection witness, honors communal and prayerful discernment, and refuses to confuse private preference or random chance with God's will. Humble obscurity is presented as faithful discipleship, not as an invitation to invent edifying details.

## Final validation

- Researcher: Catholic Daily editorial research
- Reviewer: Catholic Daily factual and theological review
- Review date: 2026-08-11
- Revision: 1
- Status: published
- Command: `dart run tool/validate_saint_profiles.dart --published-only`
- Result: PASS — 158 total, 158 legacy, 56 researched, 56 validated, 0 errors, 0 warnings
- Warnings: none
