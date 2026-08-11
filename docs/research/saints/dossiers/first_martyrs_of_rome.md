# The First Martyrs of the Holy Roman Church

## Identity resolution

- Stable ID: `first_martyrs_of_rome`
- Profile kind: group
- Celebration IDs: `first_martyrs_of_rome`, `the_first_martyrs_of_the_holy_roman_church`
- Canonical name and aliases: The First Martyrs of the Holy Roman Church; First Martyrs of the Church of Rome; First Martyrs of Rome
- Feast date and calendar scope: June 30; optional memorial in the General Roman Calendar, red, Common of Martyrs
- Identity conflicts resolved: Live Wikidata Q640666 resolves to the collective of Christians remembered as killed at Rome under Nero. The profile omits a combined lifespan and age because neither the group's membership nor every victim's chronology can be recovered. Tacitus's fire narrative, 1 Clement's early but unspecific Roman memory, Peter and Paul's distinct traditions, and later liturgical reception are not collapsed into one over-precise event.

## Source ledger

| ID | Tier | Author/institution | Title | Publisher | URL | Accessed | Reuse basis |
|---|---:|---|---|---|---|---|---|
| rome-martyrs-tacitus | 1 | Cornelius Tacitus; translated by Alfred John Church and William Jackson Brodribb | The Annals, Book XV, Chapter 44 | Perseus Digital Library, Tufts University | https://www.perseus.tufts.edu/hopper/text?doc=Tac.+Ann.+15.44 | 2026-08-11 | Primary Roman literary account used for the fire of 64, Nero's attempt to redirect suspicion, the identification and punishment of Christians in Rome, the reported large number, public cruelty, and the pity that arose; the hostile rhetoric and several-decades-later composition are explicit source limitations, and no graphic wording is reproduced |
| rome-martyrs-clement | 1 | Clement of Rome; translated by Alexander Roberts and James Donaldson | First Epistle of Clement to the Corinthians, Chapters 5–6 | New Advent | https://www.newadvent.org/fathers/1010.htm | 2026-08-11 | Early Roman Christian witness used for the community's memory of Peter and Paul followed by a great multitude who endured suffering; it does not name the victims, date the episode, mention the fire, or establish that every detail belongs to one event |
| rome-martyrs-jp2 | 1 | Pope John Paul II | General Audience of 4 July 1979 | The Holy See | https://www.vatican.va/content/john-paul-ii/en/audiences/1979/documents/hf_jp-ii_aud_19790704.html | 2026-08-11 | Formal papal reception used for the June 30 liturgical memory, its connection with Nero's Rome, Tacitus and Clement as witnesses, and the ecclesial meaning of testimony united to Christ; it is used as reception rather than as an independent contemporary chronicle |
| rome-martyrs-cook | 2 | John Granger Cook | The Historicity of the Neronian Persecution: A Response to Brent Shaw | Cambridge University Press | https://www.cambridge.org/core/journals/new-testament-studies/article/historicity-of-the-neronian-persecution-a-response-to-brent-shaw/72A73656C0F1372963C197F8945D38D3 | 2026-08-11 | Peer-reviewed historical control used for the modern dispute over Tacitus, the need to separate the punishment following the fire from Peter and Paul's martyrdom traditions, later Christian references to Nero, and the limits of calling a local episode a systematic empire-wide persecution |
| rome-martyrs-calendar | 1 | Liturgy Office, Catholic Bishops' Conference of England and Wales | Liturgical Calendar: Universal Calendar — June | Catholic Bishops' Conference of England and Wales | https://www.liturgyoffice.org.uk/Calendar/Universal/JunUC.html | 2026-08-11 | Formal calendar used for the June 30 optional memorial and title; the calendar key establishes that an entry without a printed rank is optional, while red is the established martyr color in the app calendar |

## Claim ledger

| Profile field | Claim or editorial conclusion | Source IDs | Certainty | Reconciliation note |
|---|---|---|---|---|
| identity | The celebration remembers unnamed Christians killed at Rome in Nero's reign, conventionally connected with 64. | rome-martyrs-tacitus; rome-martyrs-clement; rome-martyrs-jp2 | Mixed | Use a group profile; omit lifespan, birth data, age, names, and exact number. |
| life.fire | Tacitus says Nero redirected suspicion after the fire and punished Christians; he wrote decades later and with hostile rhetoric. | rome-martyrs-tacitus; rome-martyrs-cook | Documented report, debated reconstruction | Attribute the account to Tacitus rather than narrating every detail as direct observation. |
| life.early_roman_memory | 1 Clement remembers Peter and Paul followed by a great multitude who suffered. | rome-martyrs-clement | Reliably traditional early reception | Clement does not mention the fire or provide identities; do not silently merge its whole sequence with Tacitus. |
| life.scope | The evidence supports a Roman episode and later memory, not a detailed empire-wide campaign or single chronology including Peter and Paul. | rome-martyrs-cook; rome-martyrs-clement | Mixed | Preserve the modern dispute and separate traditions. |
| feastDates | June 30 is an optional memorial, red. | rome-martyrs-calendar; rome-martyrs-jp2 | Documented | Calendar entry has no printed rank, which the key defines as optional. |
| patronage and symbols | No reviewed formal source establishes app-compatible patronage or symbol tokens. | rome-martyrs-calendar | Low — not established | Not established by the reviewed sources; omitted from the profile. |
| spiritual guide | Fidelity is joined to Christ and applied as safe resistance to scapegoating, not admiration of cruelty or a request to seek danger. | rome-martyrs-tacitus; rome-martyrs-jp2 | Moderate pastoral synthesis | Explicitly reject graphic devotion, collective blame, anti-Jewish readings, self-endangerment, and execution-seeking. |

## Copyright and media decision

The profile is an original synthesis. Ancient texts are used through identified translations at fact and short-concept level; no extended translation is reproduced. Holy See and Cambridge prose is paraphrased. No quote object is used because no wording needs to be reproduced. No image was accepted: no specific file, creator, license, credit line, and derivative review were completed.

## Content review

- Rechecked the group identity, Roman setting, approximate 64 date, title, calendar mapping, source genres, and modern historicity dispute.
- Kept Tacitus, Clement, Peter and Paul traditions, and liturgical reception distinct.
- Removed generic legacy patronage and symbols; omitted names, exact victim count, birth data, age, and unverified individual stories.
- Confirmed the one-minute summary is within 100–150 words and the prose is original.

## Theological review

- Christ, rather than violence, is the center of martyr witness.
- No death is sought, no cruelty is described for spectacle, and endurance is not used to require staying in danger.
- The guide explicitly rejects scapegoating, collective blame, anti-Judaism, rumor, and dehumanization of any living community.
- Practices are bounded, evidence-aware, communal, and compatible with personal safety; the prayer is app-authored and Christ-centered.

## Final validation

- Researcher: Catholic Daily editorial research
- Reviewer: Catholic Daily factual and theological review
- Review date: 2026-08-11
- Revision: 1
- Status: published
- Warnings: none
- Published validator command: `dart run tool/validate_saint_profiles.dart --published-only`
- Observed result: `Saint profile validation: 158 total, 158 legacy, 76 researched, 76 validated, 0 errors, 0 warnings.`
