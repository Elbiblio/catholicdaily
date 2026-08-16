# Responsorial Psalm Edition Packs

**Date:** 2026-08-16
**Status:** Approved design
**Scope:** Full-text responsorial psalm comparison, selectable psalm editions, deterministic fallback, and runtime provenance

## Objective

The app must let a reader choose the textual edition used for responsorial psalms independently of the Bible edition used for other readings. It must preserve the proper lectionary selection and response, show complete available stanza text from the chosen edition, and fall back deterministically when that edition lacks a selection.

The supporting audit corpus must contain complete available psalm text from at least two editions for each comparison-ready normalized selection, including the text currently rendered by the app. A human reviewer must be able to compare wording, stanza boundaries, responses, and hashes without reconstructing text from another database.

## Initial Editions

The psalm-edition registry will model these sources independently of the existing Bible registry:

- Catholic Missal Nigeria / 365 Readings
- Modern Psalter, United States/Philippines
- Jerusalem Bible lectionary text
- English Standard Version Catholic Edition lectionary text
- Revised Standard Version Catholic Edition
- New American Bible Revised Edition
- Douay-Rheims Bible

An edition may have complete, partial, territory-specific, downloaded, or unavailable coverage. The UI exposes editions backed by an installed or bundled source pack. Registry metadata may describe an unavailable edition without pretending that its full text can be rendered.

## Architecture

### Psalm edition registry

A dedicated `ResponsorialPsalmEditionRegistry` describes each edition:

- stable edition ID
- display name and abbreviation
- source type: lectionary, Bible, or musical psalter
- applicable territories
- bundled, downloaded, or external storage
- provenance and edition statement
- coverage state
- fallback eligibility

This registry is separate from `BibleSourceRegistry`. Psalm-only sources do not appear as complete Bible translations and never affect the text of the first reading, second reading, Gospel, or other Scripture passages.

### Source packs

Each renderable edition is delivered as a normalized psalm source pack. Every entry contains:

- normalized selection ID
- biblical reference and selected verses
- liturgical response
- ordered stanza blocks
- territory and celebration qualifiers
- Sunday and weekday cycle qualifiers
- lectionary number when known
- source edition and source URL
- retrieval date and content hash
- display priority

Source packs share one parser and one lookup interface. Bundled CSV packs, downloaded local packs, and Bible-derived fallback packs therefore behave consistently.

### Runtime resolver

The runtime resolves psalm text in this order:

1. User-selected responsorial psalm edition.
2. Territory-specific lectionary edition for the active liturgical region.
3. User-selected Bible edition.
4. Bundled RSVCE.

The proper lectionary assignment remains authoritative throughout. Fallback changes only the textual edition used to render the already-selected verses; it must never replace a feast psalm with a weekday psalm or reorder alternatives.

The resolver returns both text and provenance:

- requested edition
- edition actually used
- whether fallback occurred
- fallback reason
- response source
- stanza-text source

The lectionary response remains independent of the chosen Bible edition. A Bible fallback supplies stanza bodies only unless a reviewed source pack explicitly contains the matching liturgical response.

## Data Products

### `psalm_text_editions.csv`

This canonical long-form corpus contains one row per normalized selection and edition. Required columns include:

- selection and usage identifiers
- normalized and raw references
- response text
- complete stanza text with preserved stanza boundaries
- edition ID, name, territory, and edition statement
- source URL, retrieval date, reuse classification, and coverage status
- raw and normalized hashes
- token count and validation state

### `psalm_text_comparison.csv`

This wide review file contains one row per unique normalized selection. It includes complete full-text columns for every available target edition:

- Catholic Missal Nigeria
- Modern Psalter
- Jerusalem Bible
- ESV-CE
- RSVCE
- NABRE
- Douay-Rheims

For each edition, the row also contains response text, stanza text, raw hash, normalized hash, coverage status, and source identifier. Comparison columns record exact equality, normalized similarity, response similarity, stanza similarity, selection mismatch, punctuation-only differences, translation differences, and missing-text reasons relative to the app-rendered baseline.

A row is `comparison_ready` only when at least two editions contain complete stanza text. Every valid normalized selection in the supported lectionary corpus must reach this state through the RSVCE and NABRE baselines even when other editions have partial coverage. Missing optional-edition text is represented explicitly rather than silently substituted in the audit file.

### `psalm_usage_map.csv`

This file maps liturgical usages to normalized selection IDs:

- date rule
- celebration ID and title
- season, week, and weekday
- Sunday and weekday cycles
- territory
- reading-set kind and priority
- lectionary number
- primary or alternative status

The usage map prevents complete text from being duplicated for every calendar occurrence.

### Committed and local outputs

The generator produces a deterministic audit set. Full-text source packs intended for runtime are stored in the appropriate bundled or downloaded pack. Comparison-only material may be generated into a local audit output while the committed audit retains provenance, hashes, metrics, and coverage facts. The build must clearly distinguish these destinations and must never silently redact a file whose contract promises complete text.

## User Interface

Settings gains a **Responsorial Psalm text** selector separate from **Bible version**.

Each edition row shows:

- edition name and abbreviation
- territory where relevant
- installed, downloadable, partial, or unavailable state
- short coverage description

The reading screen shows the edition actually used below the responsorial psalm. When fallback occurs, it displays a concise label such as `NABRE fallback — selected edition unavailable for this psalm`. The label must not interrupt the psalm itself.

Changing the psalm edition refreshes the current responsorial psalm without changing the selected Mass, reading choice, date, territory, or non-psalm Bible text.

The app displays one psalm edition at a time. Side-by-side comparison remains an audit function, not an end-user reading-screen feature.

## Validation Rules

The generator and runtime reject or quarantine entries that have:

- no normalized selection ID
- a reference inconsistent with the usage map
- no stanza text
- malformed stanza boundaries
- a response mislabeled as stanza text
- duplicate edition/selection keys with different full text and no explicit variant
- unsupported territory or cycle values
- a hash that does not match serialized full text

The comparison audit reports:

- total liturgical usages
- unique normalized selections
- unique selections per edition
- comparison-ready selections
- selections with fewer than two complete editions
- conflicting same-edition rows
- missing references, responses, or stanza text
- fallback coverage by edition and territory

## Error Handling

- A corrupt selected pack is skipped and recorded as a fallback reason.
- A missing downloaded pack does not erase the preference; the UI marks it unavailable and uses the fallback chain.
- If every source fails, the reading retains its reference and response and shows a clear text-unavailable state instead of unrelated verses.
- Network access is not required during normal reading. Downloaded packs are validated before replacing an installed copy.

## Testing

### Corpus tests

- Every comparison-ready row contains at least two complete editions.
- Every full-text cell has a reproducible hash.
- CSV quoting preserves multiline stanza text exactly.
- Long-form, wide comparison, and usage-map selection IDs reconcile.
- All comparison classes are deterministic.
- Representative Psalm and canticle selections cover numbering and verse-letter differences.

### Runtime tests

- Every installed edition can render a complete representative psalm.
- Edition selection changes psalm stanzas without changing other readings.
- Proper feast psalms remain first and alternatives remain accessible.
- The fallback chain follows selected edition, territory lectionary, selected Bible, then RSVCE.
- The actual rendered edition and fallback reason are exposed to the UI.
- Lectionary responses do not change when only the Bible edition changes.
- Corrupt or missing packs fail safely.

### Exhaustive audit

For every fixed feast, memorial, movable solemnity, Sunday cycle, weekday cycle, and authorized alternative in the supported calendar range:

- the proper selection resolves first
- each alternative remains reachable
- the selected edition is used when covered
- fallback provenance is accurate when not covered
- no unrelated psalm is substituted

## Non-Goals

- Displaying multiple editions side by side in the mobile app
- Changing the Bible edition used for non-psalm readings
- Treating a musical psalter or lectionary source as a complete Bible
- Filling missing coverage with guessed text
- Allowing text-edition fallback to alter liturgical assignment or choice order

## Completion Criteria

The feature is complete when:

1. The app has a separate responsorial psalm edition selector.
2. Every installed edition can be rendered independently.
3. Fallback follows the approved order and is labeled accurately.
4. The comparison CSV contains complete text from at least two editions for every valid normalized selection and includes the exact app-rendered baseline.
5. The generator reports remaining coverage gaps explicitly.
6. Focused, exhaustive, analysis, and full-suite gates pass.
