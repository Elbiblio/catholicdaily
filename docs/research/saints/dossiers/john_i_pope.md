# Saint John I, Pope and Martyr

## Identity resolution

- Stable ID: `john_i_pope`
- Profile kind: individual
- Celebration IDs: `john_i_pope`; `saint_john_i_pope_and_martyr`
- Canonical name and aliases: Saint John I, Pope and Martyr; Pope John I
- Feast date and calendar scope: May 18 optional memorial, red
- Lifespan and life length: omitted. Death in 526 is secure; the legacy 470 birth year is not sufficiently controlled for a calculated lifespan.
- Identity conflicts resolved: official sources establish the fifty-third pope and martyr. The embassy, imprisonment, and death are distinguished from uncertain royal motive, medical cause, and hagiographic miracle or divine-revenge motifs.

## Exact RED baseline

Before any Task 2 edit, `dart run tool/saint_research_queue.dart --ids matthias_apostle,john_i_pope,bernardine_of_siena,christopher_magallanes` exited 1. It reported `Saint research queue: 52/158 published, 0 in progress, 106 remaining.` Each of the four IDs failed because `researched JSON is not indexed`.

## Source ledger

| ID | Tier | Author/institution | Title | Publisher | URL | Accessed | Reuse basis |
|---|---:|---|---|---|---|---|---|
| john-vatican-registry | 1 | Holy See | John I | Holy See | https://www.vatican.va/content/vatican/en/holy-father/giovanni-i.html | 2026-08-11 | Official papal registry used for John as the fifty-third pope and for the documented boundaries of his pontificate, 13 August 523 to 18 May 526 |
| john-cei-martyrology | 1 | Italian Episcopal Conference | Saint of the Day: Saint John I, Pope and Martyr | Chiesa Cattolica Italiana | https://www.chiesacattolica.it/santo-del-giorno/?data-liturgia=20260518 | 2026-08-11 | Official liturgical and Martyrology source used for the May 18 optional memorial, red color, mission to Constantinople, imprisonment, death, and ecclesial recognition as martyr |
| john-liber-pontificalis | 1 | Anonymous early papal biographers; translated by Louise Ropes Loomis | The Book of the Popes (Liber Pontificalis), John I | Columbia University Press scan, Internet Archive | https://upload.wikimedia.org/wikipedia/commons/2/23/The_book_of_the_popes_%28Liber_pontificalis%29_I-_%28IA_cu31924006163897%29.pdf | 2026-08-11 | Early primary reception used cautiously for the embassy, return, imprisonment at Ravenna, and death in custody; miraculous and providential-punishment elements are excluded as hagiographic interpretation |
| john-nce | 2 | New Catholic Encyclopedia | John I, Pope, St. | Encyclopedia.com | https://www.encyclopedia.com/religion/encyclopedias-almanacs-transcripts-and-maps/john-i-pope-st | 2026-08-11 | Historical control used for Justin's anti-Arian measures, Theodoric's coerced embassy, John's qualified diplomatic response, Easter at Constantinople, disputed suspicions, and probable effects of maltreatment in custody |

## Claim ledger

| Profile field | Claim or editorial conclusion | Source IDs | Certainty | Reconciliation note |
|---|---|---|---|---|
| identity, pontificate | John was the fifty-third pope from 13 August 523 to 18 May 526. | john-vatican-registry | High | Official registry controls dates; birth year remains omitted. |
| political-religious setting | Justin restricted Arians while Theodoric's Italian rule became entangled with imperial suspicion. | john-nce | High in outline | Arian communities are not reduced to political proxies, and neither ruler's policy is idealized. |
| embassy | Theodoric compelled John to lead a mission to Constantinople seeking relief for Arians. | john-cei-martyrology; john-liber-pontificalis; john-nce | High | The mission is framed as diplomacy under constraint, not free alignment. |
| diplomatic response | John sought restoration of churches but resisted forced reconversion, according to the critical summary. | john-nce | Moderate to high | The qualified outcome is not expanded into triumph or betrayal. |
| Constantinople | John received honor and celebrated Easter in Constantinople. | john-nce; john-liber-pontificalis | High in outline | Ceremonial details receive no speculative political meaning. |
| imprisonment and death | Theodoric imprisoned John at Ravenna; he died there on May 18, 526. | john-vatican-registry; john-cei-martyrology; john-liber-pontificalis; john-nce | High | Maltreatment is probable; an exact medical cause is not asserted. |
| motive | Sources associate the imprisonment with suspicion after the embassy, but no single motive is demonstrable. | john-nce | Mixed | The profile avoids mind-reading or presenting a later accusation as proved intent. |
| hagiographic reception | The Liber Pontificalis adds miracle and divine-punishment motifs. | john-liber-pontificalis; john-nce | High as reception evidence | These are omitted as historical causation; an opponent's death is never celebrated as vengeance. |
| feast | May 18 is an optional memorial with red color. | john-cei-martyrology | High formal liturgical evidence | The older date in historical references does not override the current liturgical source. |
| patronage, symbols | Both arrays remain empty. | john-cei-martyrology; john-vatican-registry | High editorial conclusion | No formal controlled-token evidence was found. |

## Coercion, diplomacy, and martyrdom safeguard

- Eastern measures against Arians, Theodoric's pressure, John's embassy, and his later imprisonment are separate acts with separate agents.
- Arian people are treated as a religious minority with dignity, not as a convenient label for political enemies.
- The imprisonment motive and precise death mechanism remain qualified. Hagiographic causation and divine revenge are not presented as fact.
- Martyrdom names faithful witness amid abuse; it never makes detention, deprivation, forced conversion, or political retaliation desirable.

## Copyright and media decision

All papal, Martyrology, early narrative, encyclopedia, and historical prose is paraphrased. No miracle narrative, prayer, or modern translated passage is reproduced. No image is included without file-specific licensing.

## Content review

The factual pass checked pontificate dates, Italian and Byzantine setting, embassy constraints, qualified diplomatic result, Constantinople reception, imprisonment, death, feast, and source genre. Birth year, exact motive, exact medical cause, miracle claims, divine punishment, patronage, and symbols were omitted.

## Theological review

The review distinguishes fidelity from political partisanship and martyr witness from admiration of abuse. Respect for conscience applies to Arians as well as Catholics. Forgiveness does not erase accountability, and no ruler or people is assigned collective guilt.

## Final validation

- Researcher: Catholic Daily editorial research
- Reviewer: Catholic Daily factual and theological review
- Review date: 2026-08-11
- Revision: 1
- Status: published
- Command: `dart run tool/validate_saint_profiles.dart --published-only`
- Result: PASS — 158 total, 158 legacy, 56 researched, 56 validated, 0 errors, 0 warnings
- Warnings: none
