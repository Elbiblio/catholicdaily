# Nigeria Psalm 2024–2025 Verification Design

## Goal

Verify the Nigeria responsorial-psalm corpus against every recoverable 2024 and 2025 Catholic Missal Daily record without reintroducing civil-date runtime matching.

## Corpus definitions

The audit reports four distinct counts:

- base compositions: Psalm chapter or biblical canticle chapter;
- verse selections: normalized biblical reference;
- lectionary selections: normalized reference plus response;
- full-text forms: normalized reference, response, and stanzas.

Historical rows are evidence. Runtime choices remain keyed by territory plus temporal cycle, celebration and Mass form, or special-period identity.

## Acquisition

Use the installed Catholic Missal Daily application and its public data endpoints first. Recover the complete civil-date range 2024-01-01 through 2025-11-30. Preserve the original date, displayed celebration, selection order, reference, response, and stanza text. When the primary application no longer exposes a date, record the gap and use a dated matching lectionary archive only as corroboration; never synthesize wording and label it as extracted text.

## Reconciliation

Map each historical selection to the same stable usage-key model as the 2025–2026 corpus. Identical selections corroborate an existing usage. New cycle-specific selections add new usages. Different Mass forms or approved alternatives remain distinct choices. Conflicts in reference, response, or stanza text enter a comparison report and do not overwrite reviewed data automatically.

## Outputs

- a source-preserving 2024–2025 extraction CSV;
- stable usage assignments for recovered rows;
- a comparison CSV containing both full texts and an explicit match status;
- a coverage report listing recovered dates, missing dates, new usages, corroborations, and conflicts;
- updated reproducible uniqueness counts.

## Runtime behavior

The app continues to show the proper or principal feast selection first, followed by every applicable alternative. Source dates are never consulted during runtime resolution.

## Verification

Tests must fail before implementation for missing historical-year coverage. Final gates require: exact recovered-date accounting, no duplicate stable usage priorities, no source-date runtime dependency, Sunday Cycles B and C coverage, weekday Cycle I coverage, full-text comparison rows, and preservation of the existing 365-day/379-choice audit.

## Release constraint

Do not commit or push this work until extraction gaps and discrepancies have been reviewed and all automated gates pass.
