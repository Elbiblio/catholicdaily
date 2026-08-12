# Our Lady of Aparecida

## Identity resolution

- Stable ID: `our_lady_of_aparecida`
- Profile kind: `observance`
- Celebration IDs: `our_lady_of_aparecida`
- Canonical name and aliases: Our Lady of Aparecida; Our Lady of the Conception Aparecida; Solemnity of Our Lady of Aparecida
- Feast date and calendar scope: October 12; Brazilian solemnity, white
- Identity conflicts resolved: This is the Brazilian liturgical observance, not a simulated Marian biography. Live Q2469225 models the Marian title/patron entity rather than the feast event, so no Wikidata ID is published. Lifespan, life length, vocation, and places are omitted. Brazil is retained as the only formally supported patronage token; symbols remain empty.

## Source ledger

| ID | Tier | Author/institution | Title | Publisher | URL | Accessed | Reuse basis |
|---|---:|---|---|---|---|---|---|
| aparecida-shrine-history | 1 | National Shrine of Our Lady of Aparecida | História de Nossa Senhora Aparecida — Nos passos da Mãe Aparecida | A12, National Shrine of Aparecida | https://www.a12.com/santuario/historia-de-nossa-senhora-aparecida-1717 | 2026-08-12 | Institutional shrine history used for the received 1717 account naming João Alves, Felipe Pedroso, Domingos Garcia and Silvana da Rocha Alves, the image in two pieces, the 1743 report and approval, and early domestic and public devotion; miracle claims and later narrative detail are identified as devotional reception rather than independent proof |
| aparecida-domezi | 2 | Maria Cecilia Domezi | 300 anos de Aparecida: abordagem histórica. O contexto da aparição e a devoção popular | Revista de Cultura Teológica 90 (2017), pp. 179–193; published 24 January 2018; DOI 10.23925/rct.i90.35976 | https://revistas.pucsp.br/index.php/culturateo/article/view/rct.i90.35976 | 2026-08-12 | Independent historical-theological study, especially pp. 180–184, used for colonial crown power, poverty and extraction, the suffering and resistance of enslaved Black people, colonized Indigenous historical subjects, lay religious creativity, the received 1717 narrative, and the distinction between historical setting and confessional miracle interpretation; it does not identify the fishermen's ethnicity |
| aparecida-race-study | 2 | John C. Dawsey | Aparecida e a loba em performance: intersecções de gênero, raça e classe no Brasil | cadernos pagu 70 (2024), e247006 | https://periodicos.sbu.unicamp.br/ojs/index.php/cadpagu/article/download/8677464/34313 | 2026-08-12 | Open peer-reviewed study used for the dark clay image's racialized, gendered and classed reception, its deployment in Brazilian national imagination, and the need to preserve Black women's and Afro-Brazilian agency rather than naturalize a single national meaning |
| aparecida-vatican-patronage | 1 | Pope Pius XI; Sacred Congregation of Rites | Beata Virgo Maria Immaculata sub titulo Apparecida principalis Patrona Brasiliae constituitur | Acta Apostolicae Sedis 23 (1931), pp. 7–8 | https://www.vatican.va/archive/aas/documents/AAS-23-1931-ocr.pdf | 2026-08-12 | Formal juridical source used for Pius XI's 1930 proclamation of the Immaculate Virgin under the title Aparecida as principal Patroness of Brazil; formal patronage does not turn Brazil into Mary's political property or prove national favor |
| aparecida-cnbb-calendar | 1 | National Conference of Bishops of Brazil | Roteiro Celebrar em Família para a Solenidade de Nossa Senhora Aparecida | CNBB, 9 October 2020 | https://www.cnbb.org.br/wp-content/uploads/2020/09/Celebrar-em-Fam%C3%ADlia-Nossa-Senhora-Aparecida-2020.pdf | 2026-08-12 | Brazilian episcopal calendar and liturgical resource used for the exact October 12 solemnity, national scope, scriptural and Christ-centered character, and observance identity |
| aparecida-girm-color | 1 | United States Conference of Catholic Bishops | General Instruction of the Roman Missal, nos. 345–346 | USCCB, Chapter VI: The Requisites for the Celebration of Mass | https://www.usccb.org/prayer-and-worship/the-mass/general-instruction-of-the-roman-missal/girm-chapter-6 | 2026-08-12 | Formal liturgical norm used only for the white color assigned to celebrations of the Blessed Virgin Mary |

## Claim ledger

| Profile field | Claim or editorial conclusion | Source IDs | Certainty | Reconciliation note |
|---|---|---|---|---|
| profileKind; identity | October 12 is a Brazilian Marian observance, not Mary's biography. | aparecida-cnbb-calendar; aparecida-vatican-patronage | Documented | Omit person fields and wrong-model Q2469225. |
| history.1717; history.1743 | Later church records preserve the received 1717 account naming three fishermen and a damaged image found in two parts. | aparecida-shrine-history; aparecida-domezi | Mixed | The abundant catch is devotional interpretation, not independent proof. |
| history.colonial_context; history.indigenous_black_subjects | Domezi places the tradition amid crown extraction, enslaved Black suffering and resistance, and colonized Indigenous historical subjects who reworked imposed religious signs. | aparecida-domezi | Documented context | Recognize agency without inventing the fishermen's ethnicity. |
| history.racial_reception | The dark image bears racial, gendered and classed meanings shaped by Afro-Brazilian agency and national projects. | aparecida-race-study | Documented reception | No racial-harmony myth or institutional ownership of Black meaning. |
| patronage | Pius XI proclaimed Aparecida Patroness of Brazil in 1930. | aparecida-vatican-patronage | Documented formal reception | Ecclesial title, not political endorsement or guaranteed favor. |
| feastDates; calendar.rank | October 12 is a Brazilian solemnity. | aparecida-cnbb-calendar | Documented | National, not universal-calendar rank. |
| calendar.color | White applies because Aparecida is a celebration of the Blessed Virgin Mary. | aparecida-girm-color | Documented formal norm | GIRM 346 supplies color; CNBB supplies rank and date. |

## Copyright and media decision

All public prose is original synthesis. Modern shrine, Vatican, CNBB, journal, and SciELO prose is paraphrased. The venerated image and all source-page images require separate file-level rights; no image ships.

## Content review

- Kept the observance event-centered with no lifespan, vocation, places, or simulated Marian emotion.
- Distinguished the 1743 record, received 1717 narrative, and miracle interpretation.
- Named colonial extraction, enslaved Black resistance, colonized Indigenous historical subjects, Black agency, and contested national reception without assigning an ethnicity to the fishermen.
- Rejected miracle guarantees, racial harmony mythology, political ownership, and prayer replacing justice or healthcare.
- Confirmed the summary contains 100–150 words and original prose.

## Theological review

- Marian patronage directs devotion to Christ and cannot divinize Mary or certify a nation, government, or party.
- Prayer accompanies justice, anti-racism, healthcare, and responsible action; it guarantees no outcome.

## Final validation

- Researcher: Catholic Daily editorial research
- Reviewer: Catholic Daily factual and theological review
- Review date: 2026-08-12
- Revision: 1
- Status: published
- Warnings: none
- Published validator command: `dart run tool/validate_saint_profiles.dart --published-only`
- Observed result: `Saint profile validation: 158 total, 158 legacy, 124 researched, 124 validated, 0 errors, 0 warnings.`
