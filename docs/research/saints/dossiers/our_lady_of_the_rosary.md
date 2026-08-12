# Our Lady of the Rosary

## Identity resolution

- Stable ID: `our_lady_of_the_rosary`
- Profile kind: observance
- Celebration IDs: `our_lady_of_the_rosary`
- Canonical name and aliases: Our Lady of the Rosary; Memorial of Our Lady of the Rosary
- Feast date and calendar scope: October 7; obligatory memorial, white
- Identity conflicts resolved: This is the liturgical observance, not a simulated Marian biography. Q54875 is a Marian title/devotion rather than the October 7 event, so no Wikidata ID is published. Lifespan, life length, vocation, and places are omitted.

## Source ledger

| ID | Tier | Author/institution | Title | Publisher | URL | Accessed | Reuse basis |
|---|---:|---|---|---|---|---|---|
| rosary-marialis-cultus | 1 | Pope Paul VI | Marialis Cultus | The Holy See | https://www.vatican.va/content/paul-vi/en/apost_exhortations/documents/hf_p-vi_exh_19740202_marialis-cultus.html | 2026-08-12 | Formal teaching, especially sections 8 and 42–55, used for the October 7 feast, the Rosary's gradual development, Gospel and Christological center, meditative character, relationship to the liturgy, and legitimate adaptation; copyrighted wording is paraphrased |
| rosary-rvm | 1 | Pope John Paul II | Rosarium Virginis Mariae | The Holy See | https://www.vatican.va/content/john-paul-ii/en/apost_letters/2002/documents/hf_jp-ii_apl_20021016_rosarium-virginis-mariae.html | 2026-08-12 | Formal teaching used for the Rosary's gradual formation during the second millennium, contemplation of Christ with Mary, prayer for peace, and the luminous mysteries as legitimate development rather than an immutable original form |
| rosary-winston-allen | 2 | Anne Winston-Allen | Stories of the Rose: The Making of the Rosary in the Middle Ages | Pennsylvania State University Press, 1997, 224 pp. | https://www.psupress.org/books/titles/0-271-01631-0.html | 2026-08-12 | Independent scholarship used for the plurality of medieval prayer forms, Marian psalters, vernacular meditation, confraternities, and the gradual making of the Rosary; modern prose is paraphrased |
| rosary-fenlon | 2 | Iain Fenlon | Lepanto: Music, Ceremony, and Celebration in Counter-Reformation Rome | Chapter 7, pp. 139–161, in Music and Culture in Late Renaissance Italy, Oxford University Press, 2002 | https://academic.oup.com/book/49271/chapter-abstract/422785178 | 2026-08-12 | Independent historical study used for Roman musical and ceremonial celebration of Lepanto and its Counter-Reformation political and religious setting; it is not evidence of divine endorsement of war |
| rosary-calendar | 1 | Liturgy Office, Catholic Bishops' Conference of England and Wales | Liturgical Calendar: Universal Calendar — October | Catholic Bishops' Conference of England and Wales | https://www.liturgyoffice.org.uk/Calendar/Universal/OctUC.shtml | 2026-08-12 | Formal calendar used for the title Our Lady of the Rosary, October 7 obligatory memorial, and white color |

## Claim ledger

| Profile field | Claim or editorial conclusion | Source IDs | Certainty | Reconciliation note |
|---|---|---|---|---|
| profileKind | October 7 is an observance centered on the Rosary, not Mary's biography. | rosary-calendar; rosary-marialis-cultus | Documented | Omit person fields and the wrong-model Q54875. |
| history.development | The Rosary developed gradually from plural medieval prayer and meditation forms. | rosary-marialis-cultus; rosary-rvm; rosary-winston-allen | Documented development | Do not present the complete current form as handed to Dominic in a documented event. |
| doctrine.christ_centered | The Rosary contemplates Christ with Mary and remains distinct from and subordinate to liturgy. | rosary-marialis-cultus; rosary-rvm | Documented formal teaching | Mary is not divine and prayer is not an incantation. |
| history.lepanto | The feast has a military-political reception tied to the 1571 Holy League victory over Ottoman forces. | rosary-fenlon | Documented reception | Fenlon supports Roman ceremonial and political reception; acknowledge the history without anti-Muslim hostility or divine endorsement of violence. |
| practice.adaptation | Shorter or adapted prayer can preserve attention and freedom. | rosary-marialis-cultus; rosary-rvm | Documented formal pastoral teaching | No missed-decade guilt or numerical compulsion. |
| feastDates | October 7 is an obligatory memorial, white. | rosary-calendar | Documented | Formal calendar. |
| patronage; symbols | No formal compatible tokens are established for this observance. | rosary-calendar | Low — not established | Keep arrays empty. |

## Copyright and media decision

All public prose is original. Vatican documents and modern historical scholarship are paraphrased. No prayer formula or source passage is reproduced at length, and no image is shipped without file-level rights.

## Content review

- Kept the observance event-centered with no lifespan, vocation, places, or simulated Marian emotions.
- Distinguished gradual historical formation from later Dominic narratives and an immutable fifteen-mystery claim.
- Named Lepanto and Ottoman/Holy League context without hiding it or turning Muslims into timeless enemies.
- Rejected weapon language, magic, guaranteed victory, cure or protection, numerical compulsion, and substitution for healthcare, safety, justice, consent, or peacemaking.
- Confirmed the summary is 100–150 words and original.

## Theological review

- Mary directs contemplation to Christ and is neither divine nor an independent source of power.
- Prayer is free, Christ-centered, and compatible with peace, justice, healthcare, consent, and responsible action.

## Final validation

- Researcher: Catholic Daily editorial research
- Reviewer: Catholic Daily factual and theological review
- Review date: 2026-08-12
- Revision: 1
- Status: published
- Warnings: none
- Published validator command: `dart run tool/validate_saint_profiles.dart --published-only`
- Observed result: `Saint profile validation: 158 total, 158 legacy, 120 researched, 120 validated, 0 errors, 0 warnings.`
