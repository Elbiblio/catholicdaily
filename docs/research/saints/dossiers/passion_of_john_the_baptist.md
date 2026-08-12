# The Passion of Saint John the Baptist

## Identity resolution
- Stable ID: `passion_of_john_the_baptist`
- Profile kind: `observance`.
- Celebration IDs: `passion_of_john_the_baptist`, `the_passion_of_saint_john_the_baptist`.
- Canonical name and aliases: The Passion of Saint John the Baptist; The Beheading of Saint John the Baptist.
- Feast date and calendar scope: August 29, universal memorial, red.
- Identity conflicts resolved: live observance entity `Q2511873`; person entity `Q40662` and artwork entity `Q2727560` rejected. USCCB supplies the app's exact Passion title; the England and Wales calendar's Beheading wording remains an alternate regional title. No lifespan, age, vocation, places, simulated biography, or exact historical date.

## Source ledger
| ID | Tier | Author/institution | Title | Publisher | URL | Accessed | Reuse basis |
|---|---:|---|---|---|---|---|---|
| john-passion-mark6 | 1 | United States Conference of Catholic Bishops | Mark, chapter 6 | USCCB Bible | https://bible.usccb.org/bible/mark/6 | 2026-08-12 | Canonical account used for John's imprisonment, Herod's compromised decision, political banquet, execution, burial, and Mark's literary parallel with Jesus' Passion; violence is paraphrased non-graphically |
| john-passion-usccb-memorial | 1 | United States Conference of Catholic Bishops | Memorial of the Passion of Saint John the Baptist | USCCB Daily Readings, Lectionary 634 | https://bible.usccb.org/bible/readings/0829-memorial-passion-john-baptist.cfm | 2026-08-12 | Authoritative U.S. liturgical page used for the exact Passion title, memorial rank, August 29 observance, and proper Gospel from Mark 6; it is not used as evidence for historical motive or chronology |
| john-passion-matthew14 | 1 | United States Conference of Catholic Bishops | Matthew, chapter 14 | USCCB Bible | https://bible.usccb.org/bible/matthew/14 | 2026-08-12 | Canonical parallel used for John's protest, Herod's fear of the crowd, political responsibility, death, and disciples' burial; it is not expanded with later relic legends |
| john-passion-josephus | 1 | Flavius Josephus; translated by William Whiston | Antiquities of the Jews, Book 18, sections 116–119 | John E. Beardsley, 1895; Perseus Digital Library | https://www.perseus.tufts.edu/hopper/text?doc=Perseus%3Atext%3A1999.01.0146%3Abook%3D18%3Asection%3D116 | 2026-08-12 | Independent ancient historical account used for Herod Antipas's political fear of John's public influence, imprisonment at Machaerus, and execution; differences from the Gospel narrative are preserved rather than harmonized |
| john-passion-marcus | 2 | Joel Marcus | John the Baptist in History and Theology | University of South Carolina Press, 2018, 288 pp.; DOI 10.2307/j.ctv6mtfbq | https://www.jstor.org/stable/j.ctv6mtfbq | 2026-08-12 | Independent historical-critical study used to control reconstruction across Josephus and Christian sources, preserve their different theological and political emphases, and avoid treating Gospel literary presentation as a modern transcript |
| john-passion-benedict | 1 | Pope Benedict XVI | General Audience (August 29, 2012) | The Holy See | https://www.vatican.va/content/benedict-xvi/en/audiences/2012/documents/hf_ben-xvi_aud_20120829.html | 2026-08-12 | Formal Catholic reception used for the memorial's focus on truthful witness and fidelity to God; its martyr language is bounded by explicit safety, reporting, and non-danger-seeking safeguards |
| john-passion-calendar | 1 | Liturgy Office, Catholic Bishops' Conference of England and Wales | Liturgical Calendar: Universal Calendar — August | Catholic Bishops' Conference of England and Wales | https://www.liturgyoffice.org.uk/Calendar/Universal/AugUC.shtml | 2026-08-12 | Formal calendar used for the August 29 memorial and red color; its Beheading title is retained as a regional English variant, while the USCCB page supplies the app's exact Passion title |

## Claim ledger
| Profile field | Claim or editorial conclusion | Source IDs | Certainty | Reconciliation note |
|---|---|---|---|---|
| identity / observance | August 29 Memorial of the Passion of Saint John the Baptist, Q2511873 | john-passion-usccb-memorial; john-passion-calendar; john-passion-benedict | Documented formal | USCCB Passion title is exact; Beheading remains an alternate regional title. No person lifespan or biography fields. |
| Gospel event | Herod imprisons and orders John's execution after a banquet and oath | john-passion-mark6; john-passion-matthew14 | High canonical witness | Mark leaves the daughter unnamed; responsibility remains with the ruler who possessed coercive power. |
| historical event | Josephus says Herod feared John's popular influence, held him at Machaerus, and killed him | john-passion-josephus; john-passion-marcus | High ancient evidence with source limits | Josephus does not confirm the banquet and gives a different motive. |
| source conflict | Gospel and Josephus agree on Herod's responsibility but differ on motive and detail | john-passion-mark6; john-passion-josephus; john-passion-marcus | Documented difference | Accounts are not silently harmonized into a modern transcript. |
| reception | Memorial honors fidelity and truthful witness | john-passion-benedict; john-passion-calendar | Documented formal reception | It does not glorify arrest, execution, or public confrontation. |
| safeguard | Witness should use accompaniment, evidence, reporting, legal or professional help, and safety planning | john-passion-mark6; john-passion-matthew14 | Documented pastoral inference | Victims are never obliged to confront an abuser or remain in danger. |
| arrays | Patronage and symbols empty | john-passion-usccb-memorial; john-passion-calendar | Documented omission | No reviewed formal observance-level token qualified. |

## Copyright and media decision
Original synthesis and prayer. Modern Bible, Holy See, and scholarship are paraphrased; the ancient Josephus text and Whiston translation remain attributed through the Perseus edition. No image was accepted, and no head, platter, execution, or artwork image is treated as required devotional content or historical proof.

## Content review
The profile is event-centered, non-graphic, explicit about political responsibility, and candid about the different Gospel and Josephus motives. It omits exact dates, prison duration, invented last words, relic stories, and the later name Salome.

## Theological review
Truthful witness is joined to prudence, safety, justice, and care. Martyr memory never requires danger-seeking, solo confrontation, public trauma disclosure, or refusal of lawful and professional support. John, Jesus, and the Gospel setting remain within Jewish history without anti-Jewish framing.

## Final validation
- Researcher: Catholic Daily editorial research
- Reviewer: Catholic Daily factual and theological review
- Review date: 2026-08-12
- Revision: 1
- Status: published
- Warnings: none
- Published validator command: `dart run tool/validate_saint_profiles.dart --published-only`
- Observed result: `Saint profile validation: 158 total, 158 legacy, 108 researched, 108 validated, 0 errors, 0 warnings.`
