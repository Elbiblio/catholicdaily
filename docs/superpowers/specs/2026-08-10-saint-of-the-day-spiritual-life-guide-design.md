# Saint of the Day Spiritual Life Guide Design

**Date:** 2026-08-10
**Status:** Product and content foundation approved; awaiting final review of this committed specification

## Context

Catholic Daily already resolves saint-like liturgical celebrations, displays a Today’s Saints card, opens an offline saint detail page, and bundles 158 saint and Marian celebration profiles. The existing profile format is primarily biographical metadata: name, lifespan, patronage, a brief biography, feast dates, links, and sources.

The corpus is broad enough to support a meaningful first release, but it is not yet trustworthy or spiritually useful enough to make Saint of the Day a flagship feature. The current audit found short placeholder prose, repeated generic martyr and clergy templates, generic patronage, malformed sentence fragments, mojibake in names, and uneven provenance. Existing tests establish that profiles exist and open; they do not establish historical accuracy, devotional usefulness, source quality, or editorial completeness.

The Church describes saints as examples, companions in communion, and intercessors. Their lives show a path to union with Christ appropriate to different states of life (Lumen Gentium 50; Catechism of the Catholic Church 956–957 and 2683–2684). *Gaudete et Exsultate* 19–22 further describes every saint as a particular mission and Gospel message while cautioning readers to contemplate a saint’s whole journey rather than treating every recorded detail as perfect. The feature will therefore be an evidence-led spiritual life guide, not merely an encyclopedia or an unsourced devotional.

## Product principle

Every profile follows this movement:

> **Life → Gospel → Practice → Prayer**

Verified history establishes what the saint actually lived. The app then helps the reader recognize the Gospel in that life, choose a realistic response today, and pray for the grace to live it.

## Goals

- Make Saint of the Day a dependable daily reason to open Catholic Daily.
- Replace all placeholder, malformed, and generic-template content in the current 158-profile corpus.
- Give both hurried and attentive readers a useful path through each profile.
- Connect every spiritual lesson to the saint’s documented life rather than assigning generic virtues.
- Distinguish documented history, reliable tradition, legend, and disputed claims.
- Preserve source, quote, and image provenance at a level suitable for editorial review.
- Keep the complete profile useful offline after installation.
- Add a separate opt-in daily saint notification that deep-links to the correct profile.
- Retain feast reminders while preventing overlapping reminders from becoming spam.
- Support individual saints, groups, biblical figures, angels, Marian celebrations, and collective commemorations without forcing them into a false biography template.

## Non-goals

- Replacing the existing regional liturgical calendar resolver.
- Treating Wikipedia, Wikidata, or a single third-party API as an editorial authority.
- Copying copyrighted biographies, Vatican articles, devotional texts, or publisher prose.
- Generating unsupported quotations, apparitions, miracles, patronages, or private revelations.
- Presenting app-authored prayers as official liturgical collects.
- Expanding beyond the current 158 profiles before that corpus meets the release quality bar.
- Providing spiritual direction, moral diagnosis, or promises of supernatural outcomes.

## Approaches considered

### Biography-first encyclopedia

This is straightforward to research and render, but it makes the saint a historical subject rather than a companion in Christian discipleship. It does not sufficiently serve the daily spiritual purpose.

### Devotional-first reflection

This is immediately engaging but can detach lessons from historical evidence, flatten different saints into the same motivational themes, and amplify invented quotations or legends.

### Integrated evidence-led life guide — selected

The selected design layers a concise introduction, an in-depth original biography, explicit historical certainty, Gospel interpretation, practical action, reflection, and prayer. It provides inspiration without sacrificing truthfulness.

## Information architecture

### 1. Identity and feast

The header identifies the subject before offering interpretation:

- canonical display name and appropriate ecclesial title;
- aliases or birth name when useful;
- feast date and liturgical rank for the selected calendar date;
- profile kind;
- lifespan or historical period when applicable;
- vocation or state of life;
- principal places or communities associated with the subject; and
- an optional licensed image with complete attribution.

Fields that do not apply are omitted. Groups, angels, Marian celebrations, and collective commemorations do not receive artificial lifespans.

### 2. Why this saint matters today

An original two-to-four-sentence introduction states the human and spiritual relevance of the life. It must be specific enough that changing the saint’s name would make the paragraph false. This field also supplies the basis of the daily notification invitation.

### 3. In one minute

A 100–150-word original summary serves readers who cannot immediately read the full page. It includes the saint’s context, decisive response to grace, and enduring significance without becoming a list of dates.

### 4. Their life and journey

A structured 600–1,000-word narrative covers the applicable parts of:

- historical, family, and cultural context;
- vocation and formative influences;
- decisive turning points;
- opposition, suffering, sacrifice, or failure;
- prayer, Scripture, sacraments, and Christian community;
- service, mission, teaching, or reform;
- death, martyrdom, or final years; and
- beatification, canonization, or development of the celebration.

Short subsections and progressive disclosure keep the long-form account readable on mobile.

### 5. The Gospel visible in their life

This section names the particular aspect of Christ’s life or teaching embodied by the saint. Examples include mercy, fidelity, courage, contemplation, reconciliation, justice, poverty of spirit, evangelization, or care for people at the margins. It remains Christ-centred and does not present holiness as self-improvement achieved by willpower alone.

### 6. The struggle and response

One documented conflict, costly decision, weakness, loss, or sustained trial is paired with the saint’s response. This avoids sanitized hero worship and helps readers recognize growth, grace, and perseverance in real circumstances.

### 7. Virtues to imitate

Each profile contains one to three virtues. Every virtue includes:

- a plain-language name;
- the event or pattern in the saint’s life that demonstrates it; and
- a concise explanation of what imitation could mean for an ordinary person.

Generic virtue lists are not accepted.

### 8. Live it today

Each profile offers two realistic invitations:

- one five-to-ten-minute spiritual practice; and
- one concrete action involving charity, forgiveness, relationships, work, service, or responsibility.

Actions must be safe, age-appropriate for a general audience, non-manipulative, and possible without spending money. They should not use guilt, fear, or guaranteed spiritual outcomes.

### 9. Reflect

Two open examination questions connect the saint’s choices to the reader’s present life. Questions invite honest prayer and discernment rather than implying a correct emotional response.

### 10. Scripture companion

A Scripture reference is accompanied by a brief explanation of its connection to the profile’s Gospel theme. This is a devotional companion, not a replacement for the official Mass readings. The app uses its licensed or bundled Bible source and remains functional offline.

### 11. Prayer

An original short prayer asks God for a relevant grace through the saint’s intercession and ends in a Christ-centred manner. App-authored prayers are labelled as reflections from Catholic Daily and are never styled or described as official liturgical texts.

### 12. Verified words

An exact quotation or excerpt is optional. It is published only when wording, translation, authorship, and source can be verified. If no reliable quotation exists, the section is omitted rather than filled with an internet attribution.

### 13. Patronage, symbols, and traditions

These supporting facts appear below the main life guide. Each requires provenance. Traditional or legendary associations are clearly labelled and never silently merged with documented history.

### 14. Sources and editorial record

The page exposes its principal sources, historical-certainty note, image credit, and last-reviewed date. Detailed field-level evidence remains available in the bundled data or editorial ledger even when the user-facing page shows a concise source list.

## Profile kinds

The content model supports at least:

- `individual`: a saint or blessed with a biographical narrative;
- `group`: companions, martyrs, founders, or other collective witnesses;
- `biblical`: a figure primarily known through Scripture and early tradition;
- `angelic`: an angel or group of angels without a human biography;
- `marian`: a title, event, doctrine, apparition, or devotion concerning Mary;
- `collective`: All Saints, the First Martyrs, dedications, and similar celebrations; and
- `observance`: a celebration whose subject is an event or ecclesial observance rather than a single person.

Each kind has required and forbidden fields. For example, a Marian apparition profile distinguishes the Church’s approved devotional meaning from historically contested details, while an angelic profile avoids invented physical biography.

## Conceptual content model

The current flat profile evolves into structured, independently reviewable sections.

### Identity

- stable profile ID and profile kind;
- celebration IDs and aliases used for calendar matching;
- canonical name, titles, alternate names, and normalized search terms;
- lifespan or historical period;
- places, cultures, communities, vocation, and state of life;
- feast dates, local applicability, patronage, and symbols.

### Spiritual guide

- why-it-matters introduction;
- one-minute summary;
- ordered biography sections or paragraphs;
- Gospel theme;
- struggle and response;
- one to three evidence-linked virtues;
- spiritual practice and concrete action;
- two reflection questions;
- Scripture reference and connection;
- original prayer;
- optional verified quotation.

### Provenance

- source IDs attached to material claims or sections;
- source title, author or institution, publisher, URL, publication date, access date, and source tier;
- license or reuse basis where content or media is reproduced;
- historical-certainty classification and editorial note;
- image creator, work title, source page, license, attribution line, and derivative status.

### Editorial state

- `draft`, `researched`, `contentReviewed`, `theologicallyReviewed`, or `published`;
- researcher and reviewer identity;
- reviewed date and content revision;
- unresolved warnings or disputed claims.

Only profiles at the required release state are eligible for the daily notification.

## Manual research protocol

Every current profile receives an individual research dossier. Research is performed profile by profile; automated extraction can help locate or normalize facts but cannot substitute for reading and reconciling the sources.

### Minimum evidence

Use at least three credible sources when available, with at least one Tier 1 source for canonized modern saints or other subjects with accessible official documentation. Ancient or obscure saints may have fewer independent historical witnesses; the profile explicitly records that limitation instead of padding the source count.

### Source tiers

1. **Tier 1:** Holy See documents, canonization material, bishops’ conferences, liturgical texts used within their permissions, primary writings, and official archives of the relevant religious community.
2. **Tier 2:** academic scholarship, critical editions, recognized historical references, and reliable public-domain Catholic reference works.
3. **Tier 3:** Wikidata, Wikipedia, and reputable tertiary summaries used for discovery and cross-checking, never as the sole authority for a material claim.

### Research sequence

1. Confirm identity, aliases, celebration mapping, profile kind, and calendar date.
2. Locate primary or official Catholic material and the best historical reference available.
3. Build a dated source ledger and note copyright or license restrictions.
4. Record factual claims with their supporting source IDs.
5. Reconcile contradictions in dates, names, places, patronage, and reported events.
6. Classify uncertain material as documented, reliably traditional, legendary, or disputed.
7. Draft the biography and spiritual guide in original prose.
8. Verify every quotation against the exact source and translation.
9. Conduct factual/editorial review, followed by theological review of the spiritual guidance and prayer.
10. Run automated corpus validation before publication.

### Copyright and attribution

- Vatican News and other copyrighted Catholic publishers are verification and linking sources unless reuse permission explicitly allows more.
- Wikipedia prose is not copied into the offline corpus merely because it is convenient; any actual reuse must satisfy its attribution and share-alike obligations.
- Wikidata facts may assist identity and authority control under its CC0 terms.
- Wikimedia Commons media is accepted only after checking the individual file’s license and recording the required credit line.
- Public-domain texts are used only after confirming the edition and the relevant distribution jurisdiction.
- The app’s biography, reflections, practices, and prayers are original syntheses based on documented facts.

## Editorial integrity rules

- Never invent dialogue, interior motives, miracles, quotations, dates, or biographical detail.
- Never turn a disputed legend into an unqualified fact.
- Never imply that venerating a saint replaces worship of God, Scripture, the sacraments, or personal responsibility.
- Do not conceal morally complex historical context when it is material to understanding the saint.
- Avoid reducing non-European saints to geography or adversity; present their full Christian agency, culture, mission, and legacy.
- Preserve correct diacritics and Unicode spelling while retaining searchable aliases.
- Use accessible language without flattening theological meaning.
- Make practical guidance specific to the saint and proportionate to the evidence.

## Daily notification and deep link

Saint of the Day is a separate, explicit opt-in preference from Feast Day Reminders.

- The user selects a local delivery time.
- The calendar service determines the primary eligible profile for that date and region using existing liturgical precedence.
- The notification uses the why-it-matters field plus a restrained invitation, not a generic feast announcement.
- The payload contains the stable profile ID and local calendar date so a tap opens the intended dated profile on cold start, warm resume, or foreground handling.
- When several saints are commemorated, the primary profile opens first and the page lists other eligible commemorations for that day.
- If a same-day feast reminder for the same celebration would arrive within six hours of the daily saint notification, the app combines the same-day message into the Saint of the Day notification by default. An eve reminder remains distinct.
- Scheduling is idempotent across restart, time-zone change, locale change, permission change, and content revision.
- An unavailable or unpublished profile is never advertised. During the 158-profile release, a date without a researched profile receives no personalized saint notification; complete every-day coverage belongs to the expansion phase rather than a fabricated fallback profile.

### Scheduling capacity and ownership

Saint and feast notifications share one scheduling coordinator because mobile operating systems limit pending local notifications and the current feast scheduler cancels notifications globally. The implementation must not allow one category to erase the other.

- Notification IDs and cancellation are category-scoped; normal rescheduling never calls a global cancel operation.
- A shared pending-notification budget reserves capacity for both daily saints and ranked feast reminders, with a small margin below the strictest supported platform limit.
- The app schedules a rolling window of personalized saint notifications and replenishes it on app launch, settings changes, time-zone changes, content revision, and notification interaction.
- A single generic repeating notification may begin after the personalized window as a continuity fallback. Its payload resolves the saint for the actual open date, so it never names a stale saint. It is cancelled and moved forward whenever the personalized window is replenished.
- The coordinator records both the intended horizon and the latest successfully scheduled occurrence. Partial or zero scheduling never persists a false healthy horizon.
- Notification channels remain separate so the user can independently control Saint of the Day and Feast Day Reminders at the operating-system level where supported.
- Remote push is not required for the first release. If later product requirements demand indefinitely personalized daily copy without periodic app launches, a server-driven notification design requires separate privacy, reliability, and operating-cost review.

## Offline behavior and failure handling

- Published profile content, source summaries, Scripture references, and required attribution are bundled locally.
- Network access may open external source pages or retrieve optional media enhancements, but it is not required to read the life guide.
- Missing optional images produce a text-first page without layout failure.
- A profile decoding or validation failure is isolated and reported through a user-safe unavailable state; it does not break the calendar or other profiles.
- A notification is not scheduled unless its target profile validates and resolves locally.
- Legacy profiles remain readable during migration, but they are not considered research-complete and cannot drive the flagship notification until upgraded.
- Notification-tap intent is retained until onboarding and root navigation are ready. A stale, malformed, unpublished, or no-longer-matching payload falls back to the dated saints list rather than a blank or incorrect profile.
- Content revisions are versioned. A failed asset or schema migration leaves the last validated bundled corpus readable and invalidates any notification targets that no longer resolve.

## Accessibility and pastoral tone

- All sections support dynamic text, screen readers, logical heading order, and high-contrast themes.
- Images are decorative unless meaningful alt text is available; attribution remains accessible.
- Reading position and collapsed-section choices may be retained locally without requiring an account.
- Martyrdom, violence, abuse, illness, and persecution are described accurately but without graphic detail or sensational notification copy.
- Reflection prompts do not shame users, diagnose mental health, or prescribe actions that could place them at risk.

## Rollout

### Phase 1: Foundation and representative pilot

Implement the schema, validation, rendering, source ledger, and notification target contract. Research a representative pilot spanning different content kinds and editorial risks, including:

- Saint Josephine Bakhita;
- Saint Hildegard of Bingen;
- Saint Maximilian Mary Kolbe;
- Saint Martin de Porres;
- Saint Teresa of Calcutta;
- Saint Augustine Zhao Rong and Companions;
- Saints Peter and Paul;
- Saints Michael, Gabriel, and Raphael;
- Mary, Mother of God;
- Our Lady, Queen of Nigeria;
- All Saints; and
- Saint Joseph the Worker.

The pilot validates that the design works for ancient and modern saints, women and men, African and global witnesses, martyrs, founders, groups, angels, Marian celebrations, collective observances, and devotional titles.

### Phase 2: Complete the 158-profile corpus

Research the remaining profiles in controlled batches. Each batch passes the same factual, copyright, editorial, theological, schema, and UI checks. Progress is tracked by editorial state, not merely by file presence.

### Phase 3: Activate daily notifications

Enable the opt-in setting once the current 158-profile corpus is published. The setting is checked daily, but personalized notifications occur only on covered calendar dates until expansion supplies complete year-round coverage. Complete root-level deep-link lifecycle handling, shared scheduling capacity, overlap control with feast reminders, rescheduling, permission education, generic continuity fallback, and emulator verification.

### Phase 4: Ongoing expansion

After all existing profiles meet the release bar, expand coverage according to regional calendars and user need without weakening the research standard.

## Validation and testing

### Corpus validation

Automated validation rejects or reports:

- duplicate stable IDs or ambiguous celebration mappings;
- missing required fields for a profile kind;
- forbidden fields such as lifespans on angelic profiles;
- invalid dates, URLs, Scripture references, licenses, or editorial states;
- replacement characters, mojibake patterns, malformed fragments, and unexpected control characters;
- placeholder or meta-copy such as “profile available offline”;
- suspiciously duplicated biography, patronage, virtue, prayer, or action text;
- quotations without exact source linkage;
- material content sections without source support;
- images without source, creator, and license metadata;
- inconsistent lifespan, feast date, or identity facts across fields; and
- notification-eligible profiles that cannot resolve locally.

### Service and model tests

- Decode every profile kind and preserve compatibility with the current corpus during migration.
- Resolve every celebration ID and title alias deterministically.
- Select the correct primary and secondary saints for representative regional dates.
- Exclude draft or invalid profiles from notifications.
- Persist and restore the daily-notification preference and local time.
- Reschedule idempotently across time-zone and permission changes.
- Prove that rescheduling saints does not cancel feasts and rescheduling feasts does not cancel saints.
- Enforce the shared pending-notification budget and truthful scheduling horizons under partial failures.
- Resolve the generic continuity payload against the actual tap/open date.

### Widget and integration tests

- Render short and long profiles at supported text scales without overflow.
- Omit non-applicable fields cleanly for groups, angels, and Marian celebrations.
- Navigate from Today’s Saints and Browse to the same stable profile.
- Open the correct profile from notification taps on cold start and resumed app states.
- Retain a notification tap while onboarding or root navigation is still initializing.
- Present multiple commemorations without losing the primary dated context.
- Combine overlapping same-day saint and feast reminders while retaining eve reminders.
- Verify a representative notification and page journey on an Android emulator.

## Release acceptance criteria

The initial flagship release is complete only when:

- all 158 current profiles have a valid profile kind and stable celebration mapping;
- no profile contains placeholder, malformed, mojibake, or repeated generic-template prose;
- every material claim and any displayed quotation is traceable to the source ledger;
- every profile contains an original why-it-matters introduction, summary, appropriate life narrative, Gospel theme, evidence-linked virtue, practical invitation, reflection questions, Scripture companion, and prayer, except where a profile-kind rule deliberately substitutes a more suitable section;
- uncertain history is visibly classified rather than silently asserted;
- every displayed image has complete reuse and attribution data;
- each profile has completed factual/editorial and theological review;
- the complete life guide is usable offline;
- notification scheduling, overlap control, and cold/warm deep links pass automated tests and emulator verification; and
- the full Flutter test suite, static analysis, and Android debug build pass.

## Authoritative design references

- Second Vatican Council, *Lumen Gentium*, 50: <https://www.vatican.va/archive/hist_councils/ii_vatican_council/documents/vat-ii_const_19641121_lumen-gentium_en.html>
- Catechism of the Catholic Church, 956–957: <https://www.vatican.va/content/catechism/en/part_one/section_two/chapter_three/article_9/paragraph_5_the_communion_of_saints.html>
- Catechism of the Catholic Church, 2683–2684: <https://www.vatican.va/content/catechism/en/part_four/section_one/chapter_two/article_3/guides_for_prayer.html>
- Pope Francis, *Gaudete et Exsultate*, 19–22: <https://www.vatican.va/content/francesco/en/apost_exhortations/documents/papa-francesco_esortazione-ap_20180319_gaudete-et-exsultate.html>
- Wikidata licensing: <https://www.wikidata.org/wiki/Wikidata:Licensing>
- Wikimedia developer reuse guidance: <https://foundation.wikimedia.org/wiki/Legal:Wikimedia_Developer_App_Guidelines/en>
- Wikimedia Commons licensing: <https://commons.wikimedia.org/wiki/Commons:Licensing>
