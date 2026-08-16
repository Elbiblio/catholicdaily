# Responsorial Psalm Source Corpus Design

## Goal

Build an auditable, source-neutral corpus of responsorial-psalm usages and text variants, then use the verified liturgical text in the app instead of reconstructing psalms from the user's selected Bible translation. The corpus must make every candidate source comparable while preserving territory, lectionary context, stanza selection, refrain, provenance, and reuse status.

This extends the reading-choice integrity design. The resolved celebration and ordered reading set remain authoritative; this design supplies the exact responsorial-psalm text belonging to each set.

## Confirmed Failure

The current runtime combines several incompatible concepts:

- `standard_lectionary_complete.csv` supplies assignments and a generic response;
- `lectionary_psalms.csv` and `lectionary_psalms_weekday.csv` contain version-labelled response columns that are visibly misaligned in some rows;
- `LectionaryPsalmCatalogService` selects a response according to the user's RSVCE/NABRE setting;
- `ReadingsBackendIO` hydrates the stanza text from the selected Bible database;
- `PsalmResolverService` may fetch a USCCB response as a fallback.

The result can have a correct reference but the wrong response, wording, stanza boundary, territory, or lectionary translation. A responsorial psalm is a liturgical text selection; its displayed wording must not change merely because the user changes the Bible used for ordinary scripture reading.

## Verified Nigerian Comparator

The Android package `ng.com.hybridintegrated.a365dailyreadingsfornigeria` reads its Nigerian daily material from the public Firestore collection:

`projects/catholic-missal/databases/(default)/documents/NigeriaReading`

A 2026-08-16 audit found 368 documents, 358 parseable responsorial-psalm sections, 356 raw headers, and 353 normalized whole-section hashes. Those high apparent-uniqueness counts include inconsistent punctuation, spacing, reference syntax, and typographical errors; they do not represent 353 different source psalms.

Checked samples for 1 January and 15 August match the wording of the 2010 Revised Grail Psalms, while their refrains are consistent with ICEL Lectionary responses. That is an evidence-backed source classification for the checked samples, not an assumption that every record is internally consistent. The extractor must classify and compare the complete corpus.

The APK itself is not the canonical authority. It is a highly relevant Nigerian comparator and a way to locate the text actually encountered by users. CBCN Ordo assignments, exact source-edition evidence, and cross-source agreement determine production eligibility.

## Outputs

### Primary Comparison CSV

Generate `verification/psalm_sources/psalm_source_comparison.csv` in long form: one row per lectionary usage and candidate source variant. Long form keeps new sources additive and permits filtering, grouping, and pivoting without continually changing the schema.

Required columns:

| Group | Columns |
| --- | --- |
| Usage identity | `usage_id`, `celebration_id`, `celebration_title`, `date_rule`, `season`, `week`, `weekday`, `sunday_cycle`, `weekday_cycle`, `lectionary_number`, `territory`, `reading_set_kind`, `reading_set_priority` |
| Psalm identity | `biblical_book`, `psalm_number_hebrew`, `psalm_number_vulgate`, `reference_raw`, `reference_normalized`, `stanza_selection_normalized`, `response_verse_normalized` |
| Source identity | `source_id`, `source_name`, `source_edition`, `source_territory`, `source_url`, `retrieved_at`, `source_license`, `reuse_status` |
| Text | `response_raw`, `response_normalized`, `stanzas_raw`, `stanzas_normalized`, `raw_sha256`, `normalized_sha256`, `token_count` |
| Comparison | `comparison_target`, `reference_match_score`, `response_match_score`, `stanza_match_score`, `text_match_score`, `difference_class`, `review_status`, `notes` |
| Runtime eligibility | `display_eligible`, `display_priority`, `eligibility_basis` |

`reuse_status` is an explicit enum: `open`, `public_domain`, `licensed`, `comparison_only`, or `unknown`. Full text is written to the committed CSV only for `open`, `public_domain`, or `licensed` sources. Comparison-only sources may be processed locally but committed rows retain canonical references, hashes, metrics, and short diagnostic fragments rather than a bulk duplicate of the source corpus.

### Source Inventory

Generate `verification/psalm_sources/psalm_source_inventory.csv` with one row per investigated source. It records coverage, territories, edition claims, access method, rights evidence, extraction result, and whether the source can feed production text.

The first inventory must cover at least:

- Catholic Missal for Nigeria / 365 Readings public Firestore;
- Modern Psalter United States/Philippines lectionary index;
- the app's current standard, Sunday, and weekday CSVs;
- the app's local RSVCE and NABRE databases;
- official or conference-hosted regional lectionary material located during the audit;
- Revised Grail and Abbey Psalms evidence sources;
- Jerusalem Bible comparators such as the Notre Dame Newman Centre pages;
- Universalis regional pages and other stable lectionary comparators;
- genuinely open or public-domain Bible texts that could be used as a fallback, clearly distinguished from exact lectionary text.

### Runtime Catalog

Generate `assets/data/responsorial_psalm_texts.csv` only from reviewed rows where `display_eligible=true`. It contains the exact response and stanza blocks required by the app plus source attribution and a stable canonical usage key. Comparison-only rows never enter this asset.

### Audit Report

Generate `verification/psalm_sources/responsorial_psalm_audit_report.json` with counts and actionable defects:

- source and usage coverage;
- raw versus canonical unique counts;
- unmatched usages;
- conflicting references, responses, or stanza selections;
- exact and near-duplicate clusters;
- malformed source rows;
- suspected OCR or transcription errors;
- production-ineligible rows;
- feast, solemnity, memorial, weekday, Vigil, and alternative-set coverage.

## Canonicalization

Normalization exists for matching and never overwrites evidence. Every row retains raw values.

The canonicalizer must:

- recognize `Psalm`, `Ps`, canticles, and common book aliases;
- preserve Hebrew and Vulgate numbering separately;
- normalize dots, commas, semicolons, ranges, `and`, `cf.`, `see`, response notation, and verse-part letters;
- distinguish `7`, `7a`, `7ac`, and `7b-8`;
- normalize Unicode punctuation and whitespace without flattening words;
- extract repeated `R/.`, `R.`, and response-only lines;
- separate response from stanza blocks;
- remove repeated response markers from comparison text while preserving their liturgical placement in raw text;
- reject a Gospel acclamation, introduction, second reading, or prayer accidentally placed in a psalm field;
- assign stable `usage_id` and canonical stanza keys;
- report ambiguity instead of guessing when a header cannot be parsed safely.

Deduplication happens at three levels:

1. exact raw section;
2. normalized response-plus-stanzas text;
3. canonical psalm and stanza selection independent of punctuation.

This allows the audit to test the claim that the practical lectionary corpus contains fewer than roughly 200 distinct stanza selections without confusing daily reuse, header typos, or alternate refrains with new texts.

## Source Comparison

Candidate variants are compared only when their canonical selections are compatible. The comparison engine emits separate scores for:

- reference identity;
- refrain wording;
- stanza boundaries;
- normalized verse wording;
- omissions and additions.

It must classify differences as at least `exact`, `punctuation_only`, `orthography_only`, `response_only`, `stanza_boundary_only`, `translation_variant`, `selection_mismatch`, `missing_text`, or `parse_error`.

No fuzzy score can silently promote a source into production. Production eligibility is a reviewed decision supported by source edition, territory, assignment, and text agreement.

## Runtime Resolution

Introduce a dedicated responsorial-psalm text catalog. Resolution order is:

1. exact `usage_id` for the resolved reading set and territory;
2. exact lectionary number, cycle, and normalized psalm selection;
3. reviewed territory-compatible canonical selection;
4. existing Bible hydration only as an explicit last-resort fallback when no exact liturgical row exists.

The catalog returns response, stanza blocks, source edition, and provenance together. It never chooses psalm wording from the global RSVCE/NABRE preference. Bible preference continues to govern ordinary scripture hydration but not the reviewed liturgical psalm corpus.

Feast and solemnity psalms follow the reading-choice order already established: the accurate proper reading set is first, followed by legitimate Vigil or alternative sets. Each set retains its own psalm usage and text; alternatives are never collapsed merely because they share a psalm number.

## Display

The reading screen displays:

- the response before the first stanza;
- stanza blocks in lectionary order;
- the response after each stanza according to the existing responsorial layout;
- the exact alternative psalm when the user opens another legitimate reading set;
- a compact source/edition label in reading details or attribution, not in the prayer flow itself.

The UI must not expose hashes, comparison scores, audit-only fragments, or internal eligibility notes.

## Acquisition and Reproducibility

All source adapters are deterministic command-line extractors. They accept cached fixtures for tests and support a live refresh mode. Network failures do not mutate committed outputs. A refresh writes to a temporary staging directory, validates the complete output, then atomically replaces generated artifacts.

Each committed comparison row records retrieval date and source URL. Generated files use stable sorting so a second run against unchanged inputs produces no diff.

Secrets, Firebase API keys, emulator data, APKs, and raw comparison-only corpora are never committed. Public Firestore reads require no embedded secret.

## Testing

Start with failing tests for:

- parsing the Nigerian January 1 and Assumption samples into response and ordered stanzas;
- canonical equivalence across punctuation and numbering variants;
- strict distinction between verse parts and alternate stanza selections;
- deterministic CSV column order, row order, and hashes;
- source inventory coverage and valid reuse-status values;
- exclusion of comparison-only full text from committed output;
- rejection of the current misaligned response/acclamation rows;
- identification of exact Revised Grail sample matches;
- complete runtime-catalog provenance;
- Bible-version independence of liturgical psalm output;
- Assumption proper psalm text resolving before weekday or Vigil alternatives;
- preservation of all legitimate reading choices;
- whole-calendar coverage and zero silent parse failures.

Run Python extractor tests, Dart model/service tests, reading-choice regressions, focused UI tests, analyzer, and the serialized full Flutter suite. The final audit must state exact source, usage, canonical-selection, eligible-text, conflict, and unmatched counts.

## Migration and Rollback

Keep the current psalm catalogs readable during migration, but stop treating their version-labelled response columns as authoritative. Add the new runtime catalog behind tests, compare both paths across a multi-year calendar matrix, then switch the backend to the verified catalog.

Rollback is a single resolver-path change because the existing assets remain untouched until the new audit passes. Do not delete legacy CSVs in the first release.

## Success Criteria

- A reproducible CSV compares every investigated psalm source at usage, response, stanza, and text level.
- The audit identifies the true canonical unique count instead of counting formatting variants as new psalms.
- Every production psalm row has exact provenance and an explicit eligibility basis.
- Responsorial-psalm wording no longer changes with RSVCE/NABRE preference.
- The Assumption and every supported feast display their accurate proper psalm first.
- Every legitimate alternative reading set remains accessible with its own accurate psalm.
- No comparison-only corpus, APK, secret, or unreviewed text is shipped.
- Extraction, catalog resolution, exhaustive calendar audit, analyzer, and full tests pass.
