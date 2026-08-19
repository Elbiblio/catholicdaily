# Catholic Missal for Nigeria Complete Liturgical Psalm Coverage Design

## Goal

Rename the displayed psalm edition to **Catholic Missal for Nigeria** and expand its resolver coverage from a dated partial corpus to the complete set of stable Catholic liturgical usages. The implementation must cover the full Sunday A/B/C and weekday I/II cycles, every relevant proper and alternative, and Nigeria-specific celebrations without presenting another Bible edition as Nigerian missal text.

## Definitions and success criteria

The corpus has three different coverage layers, and they must remain separate:

1. **Liturgical usage inventory**: every stable calendar context that can request a responsorial psalm. This is expected to be approximately 1,114 usages, but the implementation will derive and report the exact number rather than hardcode it.
2. **Selection inventory**: the distinct lectionary reference-and-response choices reused by those usages. Catholic Daily RSVCE currently exposes 868 rows, which is a coverage baseline rather than the liturgical-day count.
3. **Text inventory**: edition-specific full stanza texts. Multiple usages and selections may reuse the same underlying text, while differences in verse ranges or responses remain distinct selections.

Completion means every stable liturgical usage resolves to all permitted selections, the proper or feast selection is ordered first, every displayed text identifies its real edition, and unresolved Nigerian wording is visibly represented as a fallback rather than silently relabeled.

## Source roles

### Catholic Missal for Nigeria

Exact captures from the Nigerian missal app are the primary evidence for Nigerian response and stanza wording. Existing dated captures may be reused across liturgical usages only when the normalized reference, response, and required verse fragments match.

### Historical Nigerian usage evidence

The reconciled 2024–2026 evidence identifies dated Nigerian calendar choices and supplies coverage across Sunday cycles A/B/C and weekday cycles I/II. Civil dates are evidence attached to stable keys; they are not runtime lookup keys.

### CatholicGallery

CatholicGallery supplies dated celebration labels, lectionary numbers, psalm references, responses, and full Douay-Rheims text. It is an independent calendar/reference cross-check and comparison edition. Its text must never be labeled as Catholic Missal for Nigeria text.

### Catholic Daily RSVCE and other local editions

The 868-row RSVCE inventory supplies a broad reference-selection baseline and remains an explicitly labeled fallback edition. It may identify missing selection coverage but may not populate Nigerian rows by renaming RSVCE wording.

### Repository lectionary and calendar data

The standard lectionary, memorial tables, Nigeria propers, and calendar services define the complete stable usage universe. The generated universe must include temporal days, special periods, fixed and movable celebrations, mass forms and vigils, Commons, optional memorial choices, and all documented alternatives.

## Architecture

### 1. Stable liturgical usage generator

Create one deterministic generator that enumerates the complete usage universe independently of civil years. It will combine:

- Sunday cycles A, B, and C;
- weekday cycles I and II;
- Advent, Christmas, Lent, Easter, and Ordinary Time;
- Holy Week and octave days;
- fixed and movable solemnities, feasts, and memorials;
- vigil, evening, and other distinct Mass forms;
- Commons and documented alternative selections;
- Nigerian national and local propers represented by the repository.

Each usage receives a stable key composed only of liturgical attributes such as territory, kind, celebration, Mass form, season, week, weekday, Sunday cycle, and weekday cycle. Civil dates remain provenance fields.

### 2. Usage-to-selection catalog

`assets/data/nigeria_psalm_usages.csv` becomes the authoritative mapping from stable usage keys to ordered selection choices. Each row records the normalized reference, response, source selection, provenance date, edition, choice priority, and review status.

Multiple valid choices for one usage are preserved. Choice priority places the proper feast or memorial psalm first while retaining temporal, Common, and alternative options for easy access.

### 3. Nigerian text-pack expansion

The Nigerian edition pack will be expanded against the complete selection inventory using this evidence order:

1. exact Nigerian source selection;
2. exact normalized Nigerian selection already captured on another date;
3. reconstruction from individually verified Nigerian verse fragments when every requested segment is available;
4. unresolved Nigerian text, served by an explicitly labeled alternate-edition fallback.

Reconstruction must preserve verse-fragment boundaries, response wording, stanza order, punctuation, and source provenance. Partial or ambiguous fragment coverage is not sufficient.

The internal source identifier and asset filename may remain stable for compatibility, but all user-visible names must read **Catholic Missal for Nigeria**. The obsolete `/ 365 Readings` suffix must be removed from the registry, generated manifest, scripts, fixtures, and tests.

### 4. Runtime resolution

The resolver accepts a liturgical context rather than a standard calendar date. It returns all ordered choices for the resolved stable key. For Nigeria, it attempts the Nigerian text pack first and then follows the existing selected-edition fallback chain while retaining the actual edition label on every result.

No ordinary date mapping may override a feast, solemnity, memorial, vigil, transferred celebration, or Nigerian proper. When several readings are legitimate, all are returned and the proper reading is first.

### 5. Coverage and comparison artifacts

Generate a comparison CSV with one row per usage-and-choice combination. Required fields include:

- stable usage key and liturgical dimensions;
- choice priority;
- reference and response;
- Nigerian text availability and provenance;
- CatholicGallery reference/text availability;
- RSVCE and other installed edition availability;
- exact, reconstructed, fallback, conflict, or missing status;
- review notes and source URLs.

A summary report will state exact counts for usages, choices, distinct references, distinct responses, exact Nigerian texts, reconstructed Nigerian texts, explicit fallbacks, conflicts, and missing items.

## Validation and error handling

Generation fails when it encounters duplicate stable keys at the same priority, invalid cycle combinations, missing references or responses, unknown celebration identifiers, ambiguous Nigerian fragment reconstruction, edition-label mismatches, or a usage with no resolvable choice.

Conflicting historical evidence remains in the comparison artifact with both sources and a conflict status. It is never resolved merely by taking the latest civil date. A reviewed override must identify the selected evidence and reason.

The manifest selection count is generated from the validated Nigerian pack. Usage coverage is reported separately and must not be represented by the selection count.

## Testing

Implementation follows test-driven development. Tests will first fail against the current partial corpus and then require:

- the exact visible name `Catholic Missal for Nigeria` everywhere;
- a deterministically generated complete stable-usage universe;
- coverage of Sunday A/B/C and weekday I/II cycles;
- coverage of all fixed, movable, vigil, Common, alternative, and Nigerian-proper contexts in source data;
- all choices retained and ordered with the proper selection first;
- no date-only runtime keys;
- no duplicate stable-key/priority pairs;
- no missing or mislabeled source editions;
- no CatholicGallery or RSVCE wording attributed to the Nigerian edition;
- exact Nigerian rows preferred over reconstructed rows, and reconstructed rows preferred over labeled fallbacks;
- complete full text for every row reported as an installed Nigerian text;
- comparison CSV row integrity and provenance;
- representative regression dates for transferred celebrations and feast-over-temporal precedence;
- full Flutter service, resolver, UI, script, corpus, analyze, and build verification.

## Scope boundaries

This work covers responsorial-psalm usage resolution, source naming, text-pack coverage, comparison artifacts, and the UI paths that display edition choices. It does not alter the wording of source editions without evidence, grant redistribution rights, or make CatholicGallery, RSVCE, or another translation part of the Nigerian edition.

## Delivery sequence

1. Capture the current incomplete-coverage tests as RED.
2. Generate and validate the full stable usage universe.
3. Reconcile CatholicGallery, historical Nigeria, and existing lectionary references against it.
4. Expand the Nigerian selection/text pack without cross-edition relabeling.
5. Update runtime resolution and the exact display name.
6. Regenerate comparison and coverage artifacts.
7. Run targeted, corpus-wide, UI, analyze, build, and full-suite verification before any release commit.
