# Saint Sixtus II, Pope, and Companions, Martyrs

## Identity resolution

- Stable ID: `sixtus_ii_pope`
- Profile kind: group
- Celebration IDs: `sixtus_ii_pope`, `saint_sixtus_ii_pope_and_companions_martyrs`
- Canonical name and aliases: Saint Sixtus II, Pope, and Companions, Martyrs; Pope Xystus II and Companions
- Feast date and calendar scope: August 7; optional memorial in the General Roman Calendar, red
- Identity conflicts resolved: Live Q127385 resolves to Sixtus II alone and is rejected for the collective liturgical memorial. No reviewed joint entity represents the group, so Wikidata ID, lifespan, and life length are omitted. Cyprian's four deacons, the Depositio's named Felicissimus and Agapitus at a distinct cemetery, and later expanded companion rosters are not forced into one unsupported list.

## Source ledger

| ID | Tier | Author/institution | Title | Publisher | URL | Accessed | Reuse basis |
|---|---:|---|---|---|---|---|---|
| sixtus-cyprian-81 | 1 | Cyprian of Carthage; translated by Robert Ernest Wallis | Epistle 81: To Successus on the Tidings Brought from Rome, Telling of the Persecution | Ante-Nicene Fathers, Volume 5, Christian Literature Publishing Co., via New Advent | https://www.newadvent.org/fathers/050681.htm | 2026-08-12 | Near-contemporary primary letter used for Valerian's rescript as reported by Cyprian, Sixtus's martyrdom in a cemetery on August 6, and four deacons killed with him; Cyprian writes as an affected bishop exhorting colleagues, not as an eyewitness or neutral administrative record |
| sixtus-depositio-354 | 1 | Anonymous Roman compiler; English translation hosted by Roger Pearse | The Chronography of 354 AD, Part 12: Commemorations of the Martyrs | Tertullian.org; source text in Monumenta Germaniae Historica, Chronica Minora I | https://www.tertullian.org/fathers/chronography_of_354_12_depositions_martyrs.htm | 2026-08-12 | Early Roman calendar used for August 6 commemoration, Xystus at Callistus, and Agapitus and Felicissimus at Praetextatus; its distinct locations are preserved and it is not expanded into a complete companion roster or narrative |
| sixtus-holy-see-chronology | 1 | The Holy See | Sixtus II | The Holy See | https://www.vatican.va/content/vatican/en/holy-father/sisto-ii.html | 2026-08-12 | Official papal chronology used for Sixtus II's pontificate from 30 August 257 to 6 August 258; its bare birthplace field is not extended into a birth date, lifespan, or detailed biography |
| sixtus-haas-valerian | 2 | Christopher J. Haas | Imperial Religious Policy and Valerian's Persecution of the Church, A.D. 257–260 | Church History, Cambridge University Press | https://www.cambridge.org/core/journals/church-history/article/abs/imperial-religious-policy-and-valerians-persecution-of-the-church-ad-257260/010A5C01BD238CB6A27E8B625710F2C2 | 2026-08-12 | Independent scholarly study used for the imperial political and religious context, the character and chronology of Valerian's targeted measures, and the limits of treating Christian martyr narratives as a complete account of policy and enforcement |
| sixtus-calendar | 1 | Liturgy Office, Catholic Bishops' Conference of England and Wales | Liturgical Calendar: Universal Calendar — August | Catholic Bishops' Conference of England and Wales | https://www.liturgyoffice.org.uk/Calendar/Universal/AugUC.shtml | 2026-08-12 | Formal calendar used for the collective title Saint Sixtus II, Pope, and Companions, Martyrs, August 7 optional memorial, and red color; the key establishes that an entry without a printed rank is optional |

## Claim ledger

| Profile field | Claim or editorial conclusion | Source IDs | Certainty | Reconciliation note |
|---|---|---|---|---|
| identity, profileKind | The liturgy commemorates Sixtus II and companions together. | sixtus-holy-see-chronology; sixtus-calendar; sixtus-cyprian-81; sixtus-depositio-354 | Documented collective reception | Use group profile; reject person-only Q127385 and omit combined lifespan. |
| life.258 | Cyprian reports Sixtus killed in a cemetery on August 6, 258, with four deacons during Valerian's persecution. | sixtus-cyprian-81 | Documented near-contemporary report | Cyprian is not eyewitness and writes exhortation; preserve genre. |
| cult.locations | The early Roman calendar locates Xystus at Callistus and Felicissimus and Agapitus at Praetextatus. | sixtus-depositio-354 | Documented early calendar | Do not collapse the two burial places. |
| companions.roster | The sources support collective memory but not one complete uncontested list. | sixtus-cyprian-81; sixtus-depositio-354 | Mixed | Four unnamed deacons and two named at another cemetery cannot silently become an exact later roster. |
| context.valerian | Valerian's measures targeted Christian leaders and other status groups within a specific imperial context. | sixtus-cyprian-81; sixtus-haas-valerian | Documented with scholarly control | Modern disagreement is not automatically persecution; do not flatten all enforcement into one uniform empire-wide scene. |
| later Passion | Speeches, exact execution staging, and farewell dialogue with Lawrence are not in the reviewed near-contemporary sources. | sixtus-cyprian-81; sixtus-depositio-354 | Low — later tradition omitted from historical core | No graphic details or fabricated last words. |
| feastDates | August 7 is an optional memorial, red. | sixtus-calendar | Documented | Distinct from the early August 6 deposit day. |
| patronage and symbols | No reviewed formal source establishes compatible tokens. | sixtus-calendar | Low — not established | Remove generic persecuted-Christians and courage tokens. |

## Copyright and media decision

The profile is original synthesis. The public-domain ancient translation is credited but not copied; modern site and scholarly prose is paraphrased. No catacomb photograph, artwork, or portrait was accepted because exact object-level rights were not verified.

## Content review

- Rechecked collective title, stable celebration IDs, August 7 optional rank, and red color.
- Resolved person/group scope by rejecting person-only Q127385, omitting combined lifespan, and preserving companion dignity.
- Preserved Cyprian's four deacons, the Depositio's two named martyrs and distinct locations, and archaeological debate without manufacturing a roster.
- Removed graphic scenes, later dialogue as fact, generic patronage, symbols, and unlicensed art.
- Confirmed the one-minute summary is 100–150 words and original.

## Theological review

- Execution and imperial coercion remain evils, never goods that Christians must seek.
- Courage includes nonviolence, escape, legal help, documentation, secure communication, trauma care, and protection of companions and dependants.
- Sparse evidence is not filled by later devotional narrative without labeling.
- Scripture connection and prayer are original.

## Final validation

- Researcher: Catholic Daily editorial research
- Reviewer: Catholic Daily factual and theological review
- Review date: 2026-08-12
- Revision: 1
- Status: published
- Warnings: none
- Published validator command: `dart run tool/validate_saint_profiles.dart --published-only`
- Observed result: `Saint profile validation: 158 total, 158 legacy, 92 researched, 92 validated, 0 errors, 0 warnings.`
