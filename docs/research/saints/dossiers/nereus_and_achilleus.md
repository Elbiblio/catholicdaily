# Saints Nereus and Achilleus, Martyrs

## Identity resolution

- Stable ID: `nereus_and_achilleus`
- Profile kind: group
- Celebration IDs: `nereus_and_achilleus`, `saints_nereus_and_achilleus_martyrs`
- Canonical name and aliases: Saints Nereus and Achilleus; Nereus and Achilleus
- Feast date and calendar scope: May 12; optional memorial
- Lifespan and life length: omitted. The exact martyrdom date and individual life chronologies are not established.
- Identity conflicts resolved: Damasus remembers two soldiers who abandoned a tyrant's service and confessed Christ. Later apocryphal Acts instead make them eunuch attendants of Flavia Domitilla in a first-century narrative. Those accounts are not silently merged.

## Exact RED baseline

The pre-edit exact queue reported `48/158 published` and failed all four Task 1 IDs because their researched JSON files were not indexed.

## Source ledger

| ID | Tier | Author/institution | Title | Publisher | URL | Accessed | Reuse basis |
|---|---:|---|---|---|---|---|---|
| nereus-damasus-inscription | 1 | Pope Damasus I; critical record by the University of Oxford Cult of Saints project | E07153: Latin Poem by Pope Damasus for Nereus and Achilleus | University of Oxford | https://portal.sds.ox.ac.uk/articles/online_resource/E07153_Latin_poem_by_Pope_Damasus_for_an_inscription_commemorating_Nereus_and_Achilleus_eunuchs_and_martyrs_of_Rome_S00403_at_their_shrine_in_the_catacomb_of_Domitilla_on_the_via_Ardeatina_outside_Rome_Written_in_Rome_366_384_/13910852 | 2026-08-11 | Primary late-fourth-century inscription in critical edition and translation, used for their names, established Roman martyr cult, military portrayal, abandonment of violent arms, confession of Christ, tomb setting, and limits of later biography; wording is not quoted |
| nereus-domitilla-archaeology | 3 | Pontifical Commission for Sacred Archaeology | Catacombs of Domitilla | Holy See | https://www.catacombeditalia.va/content/archeologiasacra/en/catacombs/by-provinces/rome/catacomb-of-domitilla.pdf | 2026-08-11 | Official archaeological summary used for the Via Ardeatina cemetery, the martyrs' basilica and burial tradition, late-fourth-century construction context, and the cautious attribution to the Diocletianic period |
| nereus-nasscal-acts | 2 | Tony Burke, North American Society for the Study of Christian Apocryphal Literature | Acts of Nereus and Achilleus | NASSCAL e-Clavis: Christian Apocrypha | https://www.nasscal.com/e-clavis-christian-apocrypha/acts-of-nereus-and-achilleus/ | 2026-08-11 | Scholarly genre control used to identify the later account as apocryphal Acts and to separate its Domitilla household, eunuch, exile, speeches, and execution narrative from earlier evidence |
| nereus-usccb-liturgy | 1 | United States Conference of Catholic Bishops | Optional Memorial of Saints Nereus and Achilleus, Martyrs | United States Conference of Catholic Bishops | https://bible.usccb.org/bible/readings/0512-memorial-nereus-achilleus.cfm | 2026-08-11 | Official liturgical page used for the May 12 optional memorial, joint martyr title, Common of Martyrs, and assigned readings |

## Claim ledger

| Profile field | Claim or editorial conclusion | Source IDs | Certainty | Reconciliation note |
|---|---|---|---|---|
| identity, cult | Nereus and Achilleus were remembered as martyrs at a shrine in the Catacomb of Domitilla by the late fourth century. | nereus-damasus-inscription; nereus-domitilla-archaeology | High for cult, sparse for biography | Cult evidence preserves their names and place but not complete lives. |
| soldiers and refusal | Damasus portrays them as soldiers who left a tyrant's violent service, laid down arms, and confessed Christ. | nereus-damasus-inscription | High for Damasan reception | The inscription is commemorative theology, not a trial transcript; no rank, unit, or claim that they persecuted Christians is added. |
| chronology | An early-fourth-century or Diocletianic setting is plausible but not exact. | nereus-domitilla-archaeology | Moderate | Lifespans and a fixed 304 death date are omitted. |
| later Acts | The Domitilla household, eunuch, first-century, Petrine, exile, dialogue, and execution details belong to later apocryphal Acts. | nereus-nasscal-acts; nereus-damasus-inscription | High genre distinction | Later reception is not used as secure biography and conflicts with the soldier portrayal. |
| feast, Scripture | May 12 is the joint optional memorial; Matthew 10:17-22 acknowledges hostile courts and promises the Spirit's help in witness. | nereus-usccb-liturgy | High formal liturgical evidence | The paired observance does not imply biological kinship or a shared synthetic lifespan, and the Gospel never authorizes leaders to expose others recklessly. |
| patronage, symbols | Both arrays remain empty. | nereus-damasus-inscription; nereus-usccb-liturgy | High editorial conclusion | Courage and persecuted Christians are themes, not formal patronage; weapons and palms are not retained symbols. |
| historicalCertainty | Early cult and Damasan reception are documented; life details and exact chronology remain uncertain. | nereus-damasus-inscription; nereus-domitilla-archaeology; nereus-nasscal-acts | Mixed | The profile explicitly separates evidence layers. |

## Martyr-memory safeguard

The profile honors fidelity while condemning execution. It does not encourage reckless exposure, shame people seeking safety, or issue blanket judgments about every military vocation. Modern imitation means refusing direct harm with lawful advice, documentation, allies, and protection for dependents. Sparse evidence is not filled with dramatic certainty.

## Copyright and media decision

The legacy fixed date, eunuch and Domitilla biography, first-century chronology, speeches, mechanics, generic patronage, and symbols are rejected as historical facts. Source prose and the Damasus translation are not reproduced. No image is included without file-specific licensing.

## Content review

The factual pass checked names, shrine, inscription date, soldier portrayal, Domitilla archaeology, optional memorial, and apocryphal Acts. It removed exact life dates, unsupported wrongdoing before conversion, legendary household detail, graphic death mechanics, patronage, and symbols.

## Theological review

Christ-centered conscience rejects a tyrant's violence while protecting life and avoiding coercive demands for martyrdom. Repentance and moral courage are communal and practical. Execution is an evil inflicted on witnesses, never the spiritual good being imitated.

## Final validation

- Researcher: Catholic Daily editorial research
- Reviewer: Catholic Daily factual and theological review
- Review date: 2026-08-11
- Revision: 1
- Status: published
- Command: `dart run tool/validate_saint_profiles.dart --published-only`
- Result: PASS — 158 total, 158 legacy, 52 researched, 52 validated, 0 errors, 0 warnings
- Warnings: none
