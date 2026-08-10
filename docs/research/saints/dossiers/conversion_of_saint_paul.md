# The Conversion of Saint Paul, Apostle

## Identity resolution

- Stable ID: `conversion_of_saint_paul`
- Profile kind: Biblical
- Celebration IDs: `conversion_of_saint_paul`, `the_conversion_of_saint_paul_apostle`
- Canonical name and aliases: The Conversion of Saint Paul, Apostle; the Conversion of Paul; the Conversion of Saul
- Feast date and calendar scope: January 25; feast in the General Roman Calendar
- Identity conflicts resolved: This is a biblical observance focused on a decisive event and apostolic call within Paul's life, not a separate person. It receives `biblical` kind and no invented lifespan. Acts 9, 22, and 26 are preserved as three rhetorically distinct tellings; Paul's own letters are privileged self-witness for revelation, appearance, grace, former persecution, and vocation. The profile does not collapse all details into a single cinematic reconstruction.

## Source ledger

| ID | Tier | Author/institution | Title | Publisher | URL | Accessed | Reuse basis |
|---|---:|---|---|---|---|---|---|
| usccb-acts-9 | 1 | United States Conference of Catholic Bishops | Acts of the Apostles, Chapter 9 | United States Conference of Catholic Bishops | https://bible.usccb.org/bible/acts/9 | 2026-08-10 | Official Catholic biblical text and notes used for Luke's narrative of persecution, encounter, Ananias, Baptism, first preaching, community suspicion, and differences among the three Acts accounts; no biblical wording is reproduced at length |
| usccb-acts-22 | 1 | United States Conference of Catholic Bishops | Acts of the Apostles, Chapter 22 | United States Conference of Catholic Bishops | https://bible.usccb.org/bible/acts/22 | 2026-08-10 | Official Catholic biblical text and notes used for Paul's defense before a Jerusalem audience, his acknowledgment of persecution, Ananias' role, Baptism, witness, and Gentile mission |
| usccb-acts-26 | 1 | United States Conference of Catholic Bishops | Acts of the Apostles, Chapter 26 | United States Conference of Catholic Bishops | https://bible.usccb.org/bible/acts/26 | 2026-08-10 | Official Catholic biblical text and notes used for the third Acts retelling before Agrippa, its compressed commission, call to deeds consistent with repentance, and distinctive rhetorical emphasis |
| usccb-galatians-1 | 1 | Saint Paul; biblical text and notes by the United States Conference of Catholic Bishops | Galatians, Chapter 1 | United States Conference of Catholic Bishops | https://bible.usccb.org/bible/galatians/1 | 2026-08-10 | Pauline self-witness and Catholic study notes used for former persecution, revelation of the Son, grace, Gentile commission, Arabia, Damascus, and the distinction between Paul's emphasis and Luke's narrative |
| usccb-1-corinthians-15 | 1 | Saint Paul; biblical text and notes by the United States Conference of Catholic Bishops | 1 Corinthians, Chapter 15 | United States Conference of Catholic Bishops | https://bible.usccb.org/bible/1corinthians/15 | 2026-08-10 | Pauline self-witness used for the risen Christ's appearance, Paul's confession that he persecuted the Church, grace, labor, and continuity with the apostolic proclamation |
| benedict-conversion-audience | 1 | Pope Benedict XVI | General Audience: St Paul's 'Conversion' | The Holy See | https://www.vatican.va/content/benedict-xvi/en/audiences/2008/documents/hf_ben-xvi_aud_20080903.html | 2026-08-10 | Official Catholic synthesis used to compare Acts with Paul's letters, center the event on the risen Christ, and affirm Baptism and communion with the Church without flattening the sources |
| benedict-feast-vespers | 1 | Pope Benedict XVI | Feast of the Conversion of St. Paul: Celebration of Vespers | The Holy See | https://www.vatican.va/content/benedict-xvi/en/homilies/2012/documents/hf_ben-xvi_hom_20120125_week-prayer.html | 2026-08-10 | Official liturgical celebration used to establish the January 25 feast and to control its interpretation as grace-led transformation in Christ rather than personal effort alone |

## Claim ledger

| Profile field | Claim or editorial conclusion | Source IDs | Certainty | Reconciliation note |
|---|---|---|---|---|
| identity, profileKind | The January 25 celebration concerns the risen Christ's decisive call of Paul from persecutor to apostle; it is an event in Paul's biblical life, not a separate lifespan. | usccb-acts-9; usccb-acts-22; usccb-acts-26; usccb-galatians-1; usccb-1-corinthians-15; benedict-conversion-audience; benedict-feast-vespers | Documented | The Holy See liturgy establishes the feast date; the JSON uses `biblical` and empty life fields as required for an event-centered profile. |
| life.former_persecution | Saul actively pursued followers of Jesus and Paul later acknowledged persecuting the Church of God. | usccb-acts-9; usccb-acts-22; usccb-acts-26; usccb-galatians-1; usccb-1-corinthians-15 | Documented | The guide names real harm and refuses to romanticize violent zeal. |
| life.encounter | Acts locates the encounter near Damascus and describes light and the voice of Jesus; Paul describes revelation of the Son and an appearance of the risen Christ. | usccb-acts-9; usccb-acts-22; usccb-acts-26; usccb-galatians-1; usccb-1-corinthians-15; benedict-conversion-audience | Documented biblical testimony | The two source types converge on Christ's initiative and Paul's apostolic call without identical narrative form. |
| life.acts_reconciliation | Acts 9 is a narrator's account, Acts 22 a defense to a Jerusalem crowd, and Acts 26 a defense before Agrippa. Companion perception and the placement of commissioning details differ. | usccb-acts-9; usccb-acts-22; usccb-acts-26; benedict-conversion-audience | Documented textual difference | Acts 9 says companions heard a voice but saw no one; Acts 22 says they saw the light but did not hear the voice of the speaker. Acts 26 compresses Ananias' mediating commission into Jesus' speech. The profile states the differences without inventing a harmonization. |
| life.ananias_baptism | Acts 9 and 22 present Ananias as ministering to Saul, who receives sight and Baptism; ecclesial reception is essential rather than optional. | usccb-acts-9; usccb-acts-22; benedict-conversion-audience | Documented biblical testimony | Acts 26's omission in a compressed courtroom speech is not treated as a denial. |
| life.mission | Paul's call included witness to Christ among Gentiles, and his later labor remained in communion with the received apostolic proclamation. | usccb-acts-9; usccb-acts-22; usccb-acts-26; usccb-galatians-1; usccb-1-corinthians-15; benedict-conversion-audience | Documented | Mission is framed as service and testimony, never conquest or cultural superiority. |
| conversion_and_repair | Grace names Paul's past, does not force injured communities to trust immediately, and becomes visible in deeds, accountable reception, and sustained labor. | usccb-acts-9; usccb-acts-22; usccb-acts-26; usccb-galatians-1; usccb-1-corinthians-15 | Moderate | This theological-editorial synthesis is grounded in the text: Acts preserves Ananias' warranted fear and community suspicion; Acts 26 joins repentance to deeds; Paul joins grace to labor. Repair is distinguished from earning forgiveness. |
| virtues, practices, scripture | Truthful repentance, ecclesial receptivity, and grace made fruitful in labor are specific Pauline applications. | usccb-acts-9; usccb-acts-22; usccb-acts-26; usccb-galatians-1; usccb-1-corinthians-15; benedict-conversion-audience; benedict-feast-vespers | High | Safety, accountability, restitution, and the harmed person's agency are explicit pastoral controls. |
| rejected precision | Exact visual sequence, psychological diagnosis, medical explanation, seamless companion-perspective harmonization, and an instant restoration of trust are omitted. | usccb-acts-9; usccb-acts-22; usccb-acts-26; usccb-galatians-1; benedict-conversion-audience | Mixed | These points are disputed, unstated, or created by forced harmonization; none is needed to confess Christ's initiative or Paul's changed vocation. |

## Copyright and media decision

Biblical passages are summarized and cited; no extended NABRE wording, papal paragraph, liturgical collect, or source-specific phrase is reproduced. The app's biography, practices, questions, and prayer are original. No image is included because file-specific licensing was not researched.

## Content review

The content review compared Acts 9, 22, and 26 line by line and then checked the Lucan accounts against Galatians 1 and 1 Corinthians 15. It preserves the different speakers, audiences, companion-perception wording, and placement of the commission. It does not imply that Paul changed religions through mere self-improvement, that communities owed him immediate trust, or that later service erased earlier victims. The event has no fabricated lifespan, and all seven source IDs appear in both ledgers.

## Theological review

The conversion is centered on the risen Christ's grace, identification with his Church, Baptism, apostolic communion, and mission. Repentance includes truth and deeds without making repair a purchase price for mercy. Mission is witness across cultural boundaries, not coercion. The prayer asks for confession, accountable guidance, patience with wounded trust, and sustained service; it neither romanticizes Paul's violence nor reduces conversion to trauma or private reinvention.

## Final validation

Separate factual/content and theological reviews were completed on 2026-08-10. Revision 1 is publishable only if dossier/profile source IDs remain identical, the biblical profile has no invented lifespan, index inclusion is unique, and all named validation commands return zero errors and warnings.
