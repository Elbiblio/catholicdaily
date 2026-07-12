# Comprehensive Readings Audit Design

## Goal

Make Catholic Daily reliable for future Mass readings across the app's supported regions and Bible versions by separating three concerns:

1. The liturgical calendar decision for a date and region.
2. The scripture references assigned to that celebration.
3. The local Bible text used to display those references.

The first implementation pass must discover and fix bugs in the existing app, especially for future dates beyond 2026, while preparing a lawful path for additional Bible text backends such as ESV-CE and Jerusalem Bible.

## Current Project Context

The app already has a strong starting point:

- `CsvReadingsResolverService` resolves a date to `DailyReading` rows from CSV and fallback data.
- `OfflineOrdoLookupService` resolves regional liturgical days, including Nigeria, England/Wales, United States, and transfer rules.
- `ReadingsBackendIo` displays text from local SQLite assets, currently `assets/rsvce.db` and `assets/nabre.db`.
- Existing tests already cover randomized dates, special days, Nigeria missal audits, region rules, and external USCCB cross-validation.
- The emulator is available as `emulator-5554`.

The worktree is currently dirty. Future implementation must preserve unrelated user changes and stage only intentional files.

## Source Grounding

The audit should use source rules rather than assumptions:

- USCCB states that the United States uses a revised Lectionary based on the New American Bible and describes the Sunday/weekday cycles and feast readings. It also notes that lectionary readings include incipits and are not raw Bible text.
- England and Wales introduced a new Lectionary from Advent 2024 based on the English Standard Version Catholic Edition with Abbey Psalms and Canticles.
- Universalis exposes local calendars, including Nigeria, England, Wales, and the United States, and can be used to compare dates, celebrations, and references.
- The Nigerian missal app store listing says it uses the Daily Readings Ordo approved by the Catholic Bishops' Conference of Nigeria, but the exact Nigerian scripture translation must be verified before claiming it as official.
- Bible translation quotation permissions are not equivalent to permission to bundle an entire offline Bible database. Full downloadable text can be used only when there is a reasonable permission basis: public domain, open license, publisher terms, explicit permission, or user-provided source with rights.

## Definitions

**Reference correctness:** the app resolves the correct date, celebration title, rank, color where applicable, scripture references, psalm reference/response, gospel acclamation reference/text, and alternatives.

**Text correctness:** the app renders the selected local Bible text for a resolved reference and version, including incipits where the app has lectionary-introduction data.

**Bundled Bible text:** a full or substantial Bible database shipped in `assets/` or otherwise redistributed with the app.

**User-provided Bible text:** a database imported by the user or developer locally and not committed or shipped as an app asset unless its rights allow redistribution.

## Regions In Scope

The comprehensive audit must cover these region profiles:

- General Roman calendar.
- United States.
- United States with Ascension Thursday.
- England and Wales.
- Nigeria.

Brazil and Mexico should remain covered by existing region tests but are not the focus of this pass unless the audit uncovers regressions there.

## Bible Versions In Scope

Existing shipped versions:

- RSVCE via `assets/rsvce.db`.
- NABRE via `assets/nabre.db`.

Prepared but not blindly bundled:

- ESV-CE, especially for England/Wales.
- Jerusalem Bible, especially for Universalis-style general and several Commonwealth calendars.
- Any Nigeria-specific ordo/text source after verification.

Additional versions must enter through a Bible source registry with metadata:

- stable id, display name, abbreviation, locale/region affinity;
- asset path or import path;
- source URL or provider;
- license or permission status;
- attribution text;
- redistribution status: `bundledAllowed`, `userProvidedOnly`, or `externalOnly`;
- whether the DB contains deuterocanonical books and Catholic canonical naming.

## Success Criteria

Automated audits must prove:

- No sampled future date resolves to an empty reading set unless the date is intentionally unsupported.
- Every ordinary weekday sample has a first reading, responsorial psalm, and gospel.
- Every Sunday and solemnity sample has first reading, responsorial psalm, second reading where expected, gospel acclamation, and gospel.
- Special days and feasts use proper readings over the ferial fallback when the region requires it.
- Region-specific transfers are honored, especially Ascension, Corpus Christi, Epiphany, All Saints, and Nigeria-specific celebrations.
- RSVCE and NABRE text rendering both work for the same resolved references.
- Missing text is reported as a text-backend gap, not as a resolver failure.
- ESV-CE/JB sources are either validly bundled, excluded from assets, or marked user-provided/external-only with clear metadata.
- Emulator validation reproduces the audited date/version/region matrix for a representative subset.

## Bug Taxonomy

Findings should be classified so fixes do not get muddled:

- `calendar`: wrong feast/weekday/season/rank/transfer.
- `reference`: right day but wrong scripture reference.
- `priority`: proper feast should override ordinary day, or vice versa.
- `cycle`: wrong Sunday cycle or weekday Year I/II.
- `region`: correct generally but wrong for US, UK, or Nigeria.
- `text-missing`: reference is correct but selected DB lacks text.
- `text-version`: text came from the wrong DB.
- `incipit`: opening phrase missing, corrupt, or from the wrong reading.
- `psalm-response`: response/refrain missing, corrupt, or wrong version.
- `ui`: service result is correct but the app screen shows stale, clipped, or incorrect content.

## Architecture Design

### Audit Harness

Create or extend a deterministic audit harness that accepts:

- date ranges;
- a fixed random seed;
- region list;
- Bible version list;
- source adapter list;
- output path under `verification/`.

It should generate a reproducible set of future dates across:

- ordinary weekdays before Lent and after Pentecost;
- Sundays in each Sunday cycle where possible;
- Advent, Christmas, Lent, Holy Week, Easter Octave, Easter season;
- fixed solemnities;
- apostle and evangelist feasts;
- Marian feasts;
- Nigeria-specific celebrations;
- US and England/Wales transfer-sensitive days;
- dates beyond 2026 that must rely on local weekday extracts.

### Source Adapters

Use separate adapters for each comparison source:

- USCCB daily readings for United States dates where pages exist.
- Universalis for general, England/Wales, and Nigeria references where available.
- Local weekday and Sunday extracts for dates beyond online coverage.
- CSV ground-truth extracts already present in `scripts/active/` where they are traceable to source files.

Adapters compare references and celebration labels. They must not require exact wording equality between different Bible translations.

### Resolver Validation

Resolver tests should call `CsvReadingsResolverService` and `OrdoResolverService` directly. They should verify normalized references, positions, alternatives, cycles, and region priority. This is the main regression layer.

### Text Backend Validation

Text tests should call `ReadingsService.getReadingText` or backend-specific APIs with each available Bible DB. They should verify:

- correct DB selection after switching Bible versions;
- no stale cache between RSVCE and NABRE;
- graceful missing-text output for absent references;
- selected version is reflected in psalm response resolution where version-specific data exists.

### Bible Source Registry

Replace the hardcoded two-version assumption with a registry that can initially expose RSVCE and NABRE, then accept ESV-CE/JB metadata later. The registry should not force all versions to be bundled. It should support:

- bundled local SQLite asset;
- developer/user local SQLite import;
- external-only source, for reference comparison but not offline rendering.

### Emulator Validation

After automated tests identify or verify fixes, run the app on `emulator-5554` and manually or semi-automatically exercise:

- region switcher;
- Bible version switcher;
- future date picker/navigation;
- selected ordinary weekday;
- selected Sunday;
- selected feast/solemnity;
- Nigeria-specific date;
- UK/England-Wales transfer-sensitive date;
- US transfer-sensitive date.

Capture UI XML/screenshots under `verification/` with date, region, and version in the filename.

## Error Handling

The app should distinguish failure modes:

- No readings resolved: calendar/reference resolver bug or unsupported date.
- Readings resolved but text unavailable: missing Bible backend coverage.
- Source unavailable during audit: mark source as skipped with HTTP/status/error, do not silently pass.
- License/permission unknown: mark source `userProvidedOnly` or `externalOnly`, do not add it to app assets.

## Testing Strategy

Use TDD for each discovered bug:

1. Add the smallest failing service-level test for the date, region, version, and expected references.
2. Verify it fails for the expected reason.
3. Implement the minimal fix.
4. Re-run the focused test.
5. Run broader resolver audits.
6. Run text-backend tests for RSVCE and NABRE.
7. Run Flutter analyzer.
8. Run emulator spot checks for representative cases.

## Documentation Outputs

Each audit run should produce:

- machine-readable JSON with date, region, version, app result, source result, status, and classification;
- human-readable Markdown summary with failures grouped by taxonomy;
- exact commands used;
- source URLs or local files used;
- any unresolved source/licensing uncertainty.

## Initial Date Matrix

The first implementation should include at least:

- 2026-07-15, ordinary weekday.
- 2026-08-15, Assumption.
- 2026-10-01, Nigeria: Our Lady, Queen of Nigeria.
- 2026-11-01, All Saints / Sunday collision.
- 2026-12-08, Immaculate Conception.
- 2027-02-17, Ash Wednesday.
- 2027-03-19, Saint Joseph / Lent interaction.
- 2027-03-25, Annunciation / Lent interaction.
- 2027-05-13, Ascension Thursday profile.
- 2027-05-16, transferred Ascension profile.
- 2027-06-06, Corpus Christi transfer-sensitive period.
- 2028-04-16, Easter Sunday.
- 2028-06-24, Nativity of Saint John the Baptist.
- 2029-07-03, Saint Thomas.
- 2030-12-25, Christmas.

The deterministic random sampler should add at least 60 more dates across 2027-2032.

## Out Of Scope For This Pass

- Shipping a full ESV-CE or Jerusalem Bible DB without a verified redistribution basis.
- Rewriting all UI screens.
- Refactoring unrelated hymn, prayer, or saint profile systems unless they block reading validation.
- Exact text equality across different Bible translations.

## Approval

This design was prepared after the user confirmed:

- correctness should prioritize celebration and scripture-reference matching;
- text should be checked through the selected local Bible DB;
- Nigeria should be included comprehensively;
- questionable downloadable Bible text should not be bundled unless there is a reasonable permission basis, but import/external support should be planned.
