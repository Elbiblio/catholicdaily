# Saint Martin de Porres

## Identity resolution

- Stable ID: `martin_de_porres`
- Profile kind: individual
- Celebration IDs: `martin_de_porres`, `saint_martin_de_porres_religious`
- Canonical name and aliases: Saint Martin de Porres; Martín de Porres; Martin of Charity
- Feast date and calendar scope: November 3; optional memorial in the General Roman Calendar
- Identity conflicts resolved: The profile uses the documented 1579-1639 dates and identifies Ana Velázquez as a freed woman of African descent from Panama. It avoids uncertain expansions about ancestry that differ among popular retellings. Extraordinary miracle traditions are acknowledged as later traditions but are not needed for the user-facing historical narrative.

## Source ledger

| ID | Tier | Author/institution | Title | Publisher | URL | Accessed | Reuse basis |
|---|---:|---|---|---|---|---|---|
| canonization-homily | 1 | Pope John XXIII | Canonization of Blessed Martin de Porres | The Holy See | https://www.vatican.va/content/john-xxiii/es/homilies/1962/documents/hf_j-xxiii_hom_19620506_martino-porres.html | 2026-08-10 | Official interpretation checked; original prose |
| dominican-biography | 1 | Dominican Friars, Province of St. Joseph | St. Martin de Porres | Dominican Friars | https://dominicanfriars.org/st-martin-de-porres-2/ | 2026-08-10 | Order biography used for vocation, prayer, healing, and dates; original prose |
| latin-american-encyclopedia | 2 | Noble David Cook | Porres, Martín de (1579-1639) | Encyclopedia of Latin American History and Culture | https://www.encyclopedia.com/humanities/encyclopedias-almanacs-transcripts-and-maps/porres-martin-de-1579-1639 | 2026-08-10 | Historical facts and colonial context only |

## Claim ledger

| Profile field | Claim or editorial conclusion | Source IDs | Certainty | Reconciliation note |
|---|---|---|---|---|
| identity | Born in Lima in 1579; died there 3 November 1639 | dominican-biography, latin-american-encyclopedia | documented | The exact baptism/birth wording varies in summaries; only the stable dates are used |
| family and race | Son of Ana Velázquez, a freed woman of African descent, and Juan de Porres, a Spaniard of standing | latin-american-encyclopedia, dominican-biography | documented | Colonial racial terminology is explained without reproducing demeaning labels |
| medical training | Apprenticed in the healing work of a barber-surgeon | latin-american-encyclopedia, dominican-biography | documented | The guide explains the period meaning and does not present him as a modern physician |
| Dominican life | Entered the Holy Rosary priory as a helper and professed as cooperator brother in 1603 | latin-american-encyclopedia, dominican-biography | documented | Limits on entry are placed in colonial context without claiming a single rule explains every stage |
| spirituality | Eucharistic and Passion devotion integrated with care of sick and poor people | dominican-biography, canonization-homily | documented ecclesial interpretation | Prayer and service are kept together |
| miracles | Popular traditions include extraordinary events | latin-american-encyclopedia | mixed | Not required for the guide; omitted from the narrative's factual claims |
| patronage | Racial harmony, mixed-race people, public health workers, and barbers | canonization-homily, dominican-biography | reliably traditional | Narrow list chosen from stable associations relevant to his documented life |
| quote | No quote included | canonization-homily; dominican-biography; latin-american-encyclopedia | documented editorial decision | No exact primary-text quotation was necessary |

## Copyright and media decision

The three sources were used for fact and interpretation checks. The app's prose is independently structured and written, with no close paraphrase of the encyclopedia or order biography. No quotation is included. No image is included in revision 1 because a particular historical artwork or photograph was not taken through the full creator/source/license verification process.

## Content review

The factual pass checked dates, Lima location, parentage, colonial racial setting, medical apprenticeship, entry into the Dominican priory, profession in 1603, Eucharistic and Passion devotion, care for sick and poor people, death, and 1962 canonization. The review removed unsupported precision about particular miracles and avoided implying that racial exclusion itself was a route to holiness. Patronage was narrowed to associations grounded in his biography and established devotion.

## Theological review

The spiritual pass confirmed that humility is not used to bless injustice or discourage resistance to unequal treatment. Christ remains the source and object of prayer; Matthew 25 connects contemplation with bodily works of mercy. The practice advises useful help while respecting professional limits and personal agency. The app-authored prayer asks both for interior conversion and action across unjust boundaries.

## Final validation

Catholic Daily editorial research completed the source and claim pass, followed by a distinct factual and theological review on 2026-08-10. Revision 1 must pass `dart run tool/validate_saint_profiles.dart --published-only` and `dart run tool/saint_research_queue.dart --ids martin_de_porres` with no error before publication.
