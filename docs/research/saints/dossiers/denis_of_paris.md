# Saint Denis, Bishop, and Companions, Martyrs

## Identity resolution

- Stable ID: `denis_of_paris`
- Profile kind: group
- Celebration IDs: `denis_of_paris`, `saint_denis_bishop_and_companions_martyrs`
- Canonical name and aliases: Saint Denis, Bishop, and Companions, Martyrs; Denis of Paris and Companions
- Feast date and calendar scope: October 9; optional memorial, red
- Identity conflicts resolved: The celebration is collective, so person-only Q244380 is omitted and no synthetic group lifespan is supplied. Denis of Paris is kept distinct from Dionysius the Areopagite and Pseudo-Dionysius.

## Source ledger

| ID | Tier | Author/institution | Title | Publisher | URL | Accessed | Reuse basis |
|---|---:|---|---|---|---|---|---|
| denis-gregory | 1 | Gregory of Tours; translated by Ernest Brehaut | History of the Franks, Book I, chapter 30 | Columbia University Press, 1916; Project Gutenberg edition | https://www.gutenberg.org/cache/epub/74955/pg74955-images.html | 2026-08-12 | Late-sixth-century narrative used as an early literary witness to Denis among missionary bishops and to received martyrdom under Decius; its chronological distance and hagiographic framing are explicit, and translated wording is not reproduced |
| denis-atlas | 2 | Michaël Wyss, Claude Dubois, Alain Erlande-Brandenburg, Robert Favreau, Françoise Gasparri, Patrick Périn, and Alain Stoclet | 1. Mausoleum et basilica | In Atlas historique de Saint-Denis, Éditions de la Maison des sciences de l'homme/OpenEdition, pp. 17–107 | https://books.openedition.org/editionsmsh/68434 | 2026-08-12 | Interdisciplinary archaeological and source synthesis used for the cemetery, first basilica, Life of Geneviève, Gregory, Hieronymian Martyrology, first Passion, companion-name chronology, and the later conflation of traditions; modern prose and images are not reproduced |
| denis-archaeology | 2 | French Ministry of Culture | Early history: Saint-Denis, une ville au Moyen Age | Ministere de la Culture | https://archeologie.culture.gouv.fr/saint-denis/en/early-history | 2026-08-12 | Public archaeological synthesis used for the late-antique cemetery, Merovingian basilica and material cult history, with the limit that archaeology cannot identify remains or verify every Passion narrative |
| denis-lapidge | 2 | Michael Lapidge | Hilduin of Saint-Denis: The Passio S. Dionysii in Prose and Verse | Brill, Mittellateinische Studien und Texte 51, Leiden/Boston, 2017, xiii + 897 pp. | https://www.degruyterbrill.com/document/isbn/9789004343627/html | 2026-08-12 | Critical edition and study used to control the Carolingian Passions and the conflation of Denis of Paris with Dionysius the Areopagite and the Pseudo-Dionysian corpus; later narrative is reception, not contemporary biography |
| denis-calendar | 1 | Liturgy Office, Catholic Bishops' Conference of England and Wales | Liturgical Calendar: Universal Calendar — October | Catholic Bishops' Conference of England and Wales | https://www.liturgyoffice.org.uk/Calendar/Universal/OctUC.shtml | 2026-08-12 | Formal calendar used for the collective title Saint Denis, Bishop, and his Companions, Martyrs, October 9 optional memorial, and red color; the calendar key establishes that an entry without a printed rank is optional |

## Claim ledger

| Profile field | Claim or editorial conclusion | Source IDs | Certainty | Reconciliation note |
|---|---|---|---|---|
| identity | An early Paris bishop-martyr is remembered with companions. | denis-gregory; denis-atlas; denis-calendar | Mixed | Collective memorial; omit person QID and group lifespan. |
| life.early_cult | Cemetery and basilica evidence establishes old material cult, not complete biography or relic identity. | denis-atlas; denis-archaeology | Documented material reception | Archaeology cannot prove Passion details. |
| reception.companions | Rusticus and Eleutherius emerge around 600. | denis-atlas | Documented textual reception | Their roles and biographies are not independently recoverable. |
| reception.legend | Montmartre route, elaborate tortures, and head-carrying are later hagiography. | denis-atlas; denis-lapidge | Documented reception | Do not render graphically or as historical proof. |
| reception.conflation | Paris Denis, Acts 17 Areopagite, and Pseudo-Dionysius are different figures. | denis-atlas; denis-lapidge | Documented critical conclusion | Do not attribute the mystical corpus to Denis of Paris. |
| feastDates | October 9 is an optional memorial, red. | denis-calendar | Documented | Formal calendar. |
| patronage; symbols | No reviewed formal group tokens were established. | denis-calendar | Low — not established | Keep arrays empty. |

## Copyright and media decision

Ancient base text is public domain, while the Brehaut translation, Atlas, Ministry synthesis, and Lapidge study are source-controlled and paraphrased. No image or manuscript reproduction is used.

## Content review

- Preserved collective scope and the near-total loss of companion biography.
- Separated material cult, Gregory, companion-name reception, Passion, cephalophore story, and Carolingian conflation.
- Rejected graphic spectacle, danger-seeking, anti-Roman or anti-pagan hostility, monarchy, nationalism, and relic proof.
- Affirmed prudent escape, documentation, accompaniment, and lawful help when threatened.
- Confirmed the summary is 100–150 words and original.

## Theological review

- Martyrdom is framed as faithful, nonviolent witness rather than danger-seeking or proof through suffering.
- The prayer rejects spectacle, hatred, and nationalist possession while preserving prudence and protection.

## Final validation

- Researcher: Catholic Daily editorial research
- Reviewer: Catholic Daily factual and theological review
- Review date: 2026-08-12
- Revision: 1
- Status: published
- Warnings: none
- Published validator command: `dart run tool/validate_saint_profiles.dart --published-only`
- Observed result: `Saint profile validation: 158 total, 158 legacy, 120 researched, 120 validated, 0 errors, 0 warnings.`
