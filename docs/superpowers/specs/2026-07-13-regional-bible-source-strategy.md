# Regional Bible Source Strategy

## Goal

Determine the best working text strategy for Nigeria, England/Wales, and the United States using local Bible databases plus public online sources/APIs where possible.

The core rule is now word-sequence based: exactness means the same ordered normalized words after ignoring punctuation, verse-number rendering, quote style, dash style, and whitespace. Raw character equality is too brittle for lectionary work.

## Source Findings

### United States

Official/current source:

- USCCB daily readings are from the `Lectionary for Mass for Use in the Dioceses of the United States, second typical edition`.
- USCCB daily reading pages carry a lectionary copyright notice for `2001, 1998, 1997, 1986, 1970 Confraternity of Christian Doctrine`.
- USCCB Bible pages and FAQ identify the New American Bible Revised Edition (`NABRE`) as the current Bible text, but the Mass reading pages are lectionary pages, not a generic Bible API response.

Implication:

- `assets/nabre.db` is a useful local backend, but it should not be treated as exact US lectionary text in every case.
- Exact US audit should use USCCB daily-reading pages or cached/user-provided US lectionary extracts.
- The app label should eventually distinguish `NABRE Bible backend` from `US Lectionary exact text`.

Working strategy:

1. Keep `nabre.db` as the bundled US-local rendering backend.
2. Add Bolls `NABRE` as an online Bible-text comparator/source, stripping HTML/footnote markers before normalized word-sequence comparison.
3. Add/keep a USCCB daily-reading source adapter for online/cached exact-text audits, because USCCB pages are lectionary text and include liturgical context beyond generic NABRE chapter text.
4. Use normalized word-sequence comparison for exactness.
5. Use surgical opening replacement only when a USCCB/cached/Bolls source has the same reference and a unique 10-word or 50-character early anchor.
6. Track future US transition: public reporting says a new `Catholic American Bible` is intended to replace NABRE/US lectionary text in future liturgical use, so the source registry should support future US text-family versioning.

### England and Wales

Official/current source:

- The new Lectionary came into use in Advent 2024.
- The readings use the `English Standard Version - Catholic Edition` (`ESV-CE`).
- Responsorial Psalms use the `Abbey Psalms and Canticles`.

API/source reality:

- Crossway provides an official ESV API for non-commercial use with an API key.
- That API is for `ESV`; it should not be assumed to be exact `ESV-CE`, and it does not solve Abbey Psalm text.
- Bolls exposes keyless `ESV`, but I did not find `ESV-CE` there.
- Universalis states that on the web its Mass readings are from the Jerusalem Bible, while downloadable versions use ESV in Great Britain. Its public web site is also limited to yesterday, today, and the week ahead.

Implication:

- RSVCE is not the exact England/Wales current lectionary text.
- A generic ESV API is useful as a close comparator, not a final exact source.
- Exact England/Wales support requires one of:
  - licensed/bundled ESV-CE + Abbey Psalms source;
  - user-provided local ESV-CE/lectionary database;
  - authorized online API/source that explicitly serves ESV-CE and Abbey Psalms;
  - cached/user-provided lectionary extracts for audit-only validation.

Working strategy:

1. Keep `esvce` as an external/user-provided source family in the registry.
2. Do not claim RSVCE output is exact for GB/EW after Advent 2024.
3. Use Crossway ESV API or Bolls `ESV` only as diagnostic comparators, not as exact GB/EW text, unless ESV-CE access is separately verified.
4. Use cached extracts or a licensed/user-provided local ESV-CE DB for exact GB/EW rendering.
5. Treat Abbey Psalms separately from Bible passage APIs.

### Nigeria

Official/current source status:

- I did not find a clean, authoritative public Nigerian bishops' source that states the exact English Bible text family for the Nigerian lectionary.
- Practical evidence from the app/user reports indicates `RSVCE` matches Nigerian readings very well, reportedly above 95%.
- Bolls exposes `RSV2CE` publicly and quick sample checks matched the bundled `rsvce.db` on 4 of 5 sampled verses. The remaining sample mismatch appeared to be a tokenization/format artifact around a name rather than a clear translation-family mismatch. Bolls `RSV2CE` is therefore a strong comparator, but every automated use should still be verified row-by-row with normalized word-sequence checks.
- Universalis says its web Mass readings are Jerusalem Bible, and downloadable versions use Jerusalem Bible outside the USA and Great Britain, but that is a Universalis product/text policy, not proof of the Nigerian bishops' exact printed lectionary text.

Implication:

- Nigeria should be treated as `RSVCE-compatible by evidence`, not `officially proven RSVCE` until a local official/source citation is found.
- The current bundled `rsvce.db` is still the best working local backend for Nigeria.
- Remaining mismatches are likely from:
  - local calendar/feast differences;
  - lectionary incipits;
  - psalm refrains;
  - occasional translation/source differences.

Working strategy:

1. Make Nigeria default to `rsvce.db`.
2. Add Bolls `RSV2CE` as an online comparator/source for Nigeria, with row-level normalized word-sequence verification against bundled `rsvce.db`.
3. Validate using Nigerian calendar samples and normalized word-sequence comparison.
4. Build a Nigeria exact-text fixture set from reliable local/user-provided extracts or official missal pages when available.
5. Use surgical opening replacement for Nigeria only when the RSVCE-rendered text and source opening share a unique early anchor of at least 10 words or 50 normalized characters.
6. Use Universalis/Jerusalem Bible only as secondary calendar/reference comparison, not as proof of exact Nigerian rendered text.

## Public API Assessment

### Crossway ESV API

Status:

- Official ESV API.
- Requires API key.
- Free for non-commercial use.

Use:

- Good comparator for ESV-family readings.
- Not enough by itself for exact GB/EW because GB/EW uses ESV-CE plus Abbey Psalms.

### BibleGateway API

Status:

- API endpoint responds, but requires an access token.
- Translation access depends on authorization.

Use:

- Potential online source if we can get a token and confirm it exposes `RSVCE`, `NABRE`/NAB lectionary-relevant text, and/or ESV-CE.
- Do not depend on it for runtime until access and exact text-family coverage are verified.

### Bolls Bible API

Status:

- Keyless public API.
- Translation list includes important Catholic/near-Catholic candidates:
  - `RSV2CE`
  - `NABRE`
  - `NRSVCE`
  - `NJB1985`
  - `DRB`
  - `ESV`
- Chapter endpoint shape works, for example:
  - `https://bolls.life/get-text/RSV2CE/John/3/`
  - `https://bolls.life/get-text/NABRE/John/3/`
  - `https://bolls.life/get-text/NRSVCE/John/3/`
  - `https://bolls.life/get-text/NJB1985/John/3/`

Use:

- Best discovered keyless online Bible source for our Catholic text-family comparisons.
- Good external comparator for Nigeria (`RSV2CE`) and US (`NABRE`).
- Helpful comparator for Jerusalem/New Jerusalem family (`NJB1985`) and NRSV Catholic (`NRSVCE`).
- Quick probes matched Bolls `RSV2CE` to bundled `rsvce.db` on 4 of 5 sampled verses, with the exception looking like token splitting around a name.
- Quick probes matched Bolls `NABRE` to bundled `nabre.db` on 4 of 5 sampled verses, with the exception caused by a local DB heading preceding the verse words.
- Not a lectionary API: it does not provide regional incipits, psalm refrains, feast choices, or USCCB/GB lectionary adaptations.
- Treat as online/external source, not bundled asset, unless we separately verify copyright/redistribution terms for each translation.
- Strip HTML tags, superscript footnotes, note markers, and headings before normalized word-sequence comparison.

### API.Bible

Status:

- Offers public-domain and copyrighted Bible access under plans.
- Requires account/key and selected licensed versions.

Use:

- Potential provider for API-backed Bible text.
- Needs version inventory verification for `RSVCE`, `ESV-CE`, and `NABRE`.
- It will still not provide lectionary incipits or Abbey Psalm/USCCB lectionary adaptations unless those exact texts are licensed.

### bible-api.com and public-domain APIs

Status:

- No-key public API works for public-domain/free translations such as WEB/KJV.

Use:

- Not suitable for exact Catholic regional readings.
- Useful only for tooling smoke tests.

### USCCB Daily Reading Pages

Status:

- Public official daily-reading pages.
- Not a clean JSON API.
- Scripted simple HTTP can work for specific pages, though robust extraction may need HTML parsing/caching.

Use:

- Best online source for US exact lectionary audits.
- Use cached pages and normalized word-sequence comparison.

### Universalis

Status:

- Public web pages are reachable for current-window Mass readings.
- Web Mass readings are Jerusalem Bible.
- Downloadable versions use New American Bible in USA, ESV in Great Britain, and Jerusalem Bible elsewhere.
- Public web pages are limited to yesterday, today, and the week ahead.
- Responsorial Psalms are not fully available on the web.

Use:

- Good public current-window calendar/reference comparator.
- Good Jerusalem Bible comparator.
- Not sufficient for future multi-year exact extraction without app/program/e-book access or cached/user-provided source.

## Final Region Fix Strategy

### Nigeria

Implementation target:

- `region: NG`
- default Bible backend: `rsvce`
- exactness mode: normalized word sequence
- source confidence: empirical/high, official citation still needed

Fix path:

1. Keep RSVCE as the Nigeria default.
2. Use Bolls `RSV2CE` as the first online comparator for Bible passage words.
3. Expand Nigeria fixtures across ordinary time, Sundays, solemnities, and Nigerian proper celebrations.
4. Classify mismatches as calendar/reference, incipit-only, psalm-refrain, or translation mismatch.
5. Use surgical opening adapter only for anchored incipit differences.
6. Do not import Jerusalem Bible as Nigeria default unless source evidence beats RSVCE.

### England/Wales

Implementation target:

- `region: GB_EW`
- exact Bible text: `ESV-CE`
- psalms: `Abbey Psalms and Canticles`
- current bundled exact backend: none

Fix path:

1. Stop treating RSVCE as exact for GB/EW current lectionary.
2. Keep RSVCE only as a fallback/legacy comparator if exposed at all.
3. Add `esvce` as user-provided/API-backed renderable source.
4. Use Bolls/Crossway `ESV` only for approximate comparator checks, not exact claims.
5. Add `abbey_psalms` as a separate psalm text-family requirement.
6. Until licensed/user-provided ESV-CE exists, mark GB/EW exact-text rendering as unavailable/external-only rather than pretending RSVCE is exact.

### United States

Implementation target:

- `region: US`, `US_ASC_THU`
- local backend: `nabre`
- exact lectionary source: USCCB daily reading pages / US Lectionary for Mass text family

Fix path:

1. Keep NABRE local backend as useful and close.
2. Use Bolls `NABRE` as a keyless online Bible passage comparator/source.
3. Do not call local NABRE exact for every US lectionary reading.
4. Add USCCB page adapter for exact audit and high-confidence online rendering when online mode is allowed.
5. Cache extracted USCCB openings/fingerprints for audit-only use.
6. Keep an upgrade path for the future Catholic American Bible / revised US lectionary text family.

## Engineering Changes Implied

1. Add `BibleSource` metadata fields:
   - `textFamily`
   - `lectionaryTextFamily`
   - `psalmTextFamily`
   - `exactForRegionCodes`
   - `approximateForRegionCodes`
   - `sourceConfidence`

2. Add region text profiles:
   - `NG`: RSVCE exact-compatible by evidence.
   - `GB_EW`: ESV-CE + Abbey Psalms required.
   - `US`: US Lectionary/NAB-family, USCCB exact source; NABRE approximate local backend.

3. Add source adapters:
   - `UsccbDailyReadingSourceAdapter`
   - `BollsBibleSourceAdapter`
   - `UniversalisCurrentWindowSourceAdapter`
   - `ExternalBibleApiSourceAdapter` for key-based APIs
   - `UserProvidedBibleDbSourceAdapter`

4. Update UI labels:
   - Avoid presenting approximate text as exact regional lectionary text.
   - Show when a region requires external/user-provided text for exact parity.

5. Continue using normalized word-sequence exactness:
   - exact audit: full ordered word sequence match;
   - surgical opening: unique early 10-word or 50-character anchor;
   - catalog-only: 5-word or 25-character opening.

## Decision

The final working strategy is hybrid, not one API:

- Nigeria: ship/work from RSVCE locally, use Bolls `RSV2CE` as external comparator, verify aggressively.
- United States: use local NABRE plus Bolls `NABRE` as Bible backend/comparator, USCCB pages for exact lectionary audit/source.
- England/Wales: require ESV-CE + Abbey Psalms; do not claim exactness until an API/license/user-provided source is connected.

This gives us reliable behavior per region without falsely treating public Bible APIs as complete lectionary APIs.

## Source References

- England/Wales Liturgy Office FAQ: `https://www.liturgyoffice.org.uk/Resources/Lectionary/LM-FAQ.shtml`
- England/Wales Lectionary resource page: `https://www.liturgyoffice.org.uk/Resources/Lectionary/index.shtml`
- CBCEW Lectionary FAQ: `https://www.cbcew.org.uk/lectionary-frequently-asked-questions/`
- USCCB daily reading page example: `https://bible.usccb.org/bible/readings/041226.cfm`
- USCCB Bible FAQ: `https://www.usccb.org/faq`
- USCCB liturgical publication guidelines: `https://www.usccb.org/committees/divine-worship/policies/guidelines-for-the-publication-of-liturgical-books`
- ESV API overview: `https://api.esv.org/`
- ESV passage text endpoint docs: `https://api.esv.org/docs/passage-text/`
- BibleGateway API documentation: `https://www.biblegateway.com/api/documentation`
- Bolls translation list endpoint: `https://bolls.life/static/bolls/app/views/languages.json`
- Bolls RSV2CE chapter example: `https://bolls.life/get-text/RSV2CE/John/3/`
- Bolls NABRE chapter example: `https://bolls.life/get-text/NABRE/John/3/`
- API.Bible plans and non-commercial limits: `https://api.bible/`
- API.Bible authentication docs: `https://scripture.api.bible/docs`
- bible-api.com translation docs: `https://bible-api.com/`
- Universalis Mass readings page: `https://universalis.com/mass.htm`
