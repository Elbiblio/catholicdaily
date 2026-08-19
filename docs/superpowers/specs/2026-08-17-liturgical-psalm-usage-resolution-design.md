# Liturgical Psalm Usage Resolution Design

## Problem

The Nigerian psalm import currently treats each source record's Gregorian date
as its runtime identity. That model is incorrect: responsorial psalm texts recur,
while their liturgical use belongs to a temporal day, a celebration proper, or a
specific Mass form. A date can also expose several legitimate reading sets, such
as the weekday and an optional memorial. Looking up every psalm attached to that
date mixes those sets and cannot safely recur in another lectionary year.

## Design principles

- Gregorian source dates remain provenance only.
- Psalm text and psalm usage are separate data concerns.
- Every runtime usage has one stable liturgical identity.
- Every available reading set resolves independently.
- Celebration propers and their Mass forms take precedence over temporal uses.
- Text-edition fallback may change rendered stanza wording, but never the
  selected reference, response, or liturgical usage.
- Ambiguous or unmatched imported rows fail generation and remain undisplayed.

## Stable usage identities

### Celebration usage

A proper is keyed by:

- territory;
- celebration ID;
- Mass form (`day`, `vigil`, `night`, `dawn`, or another explicit form);
- choice priority.

Fixed calendar dates are not part of this key. The same proper therefore follows
the celebration when it is transferred.

### Temporal usage

A temporal psalm is keyed by:

- territory;
- season or special period;
- week number or special-period day;
- weekday;
- Sunday cycle or weekday cycle, as applicable;
- reading-set form;
- choice priority.

Movable days such as Easter Vigil use an explicit special-period identity rather
than a computed Gregorian date.

## Data model

The generated Nigerian source data will expose two logical datasets:

1. A deduplicated text corpus keyed by normalized selection/reference and source
   edition, containing the response and complete stanza text.
2. A usage catalog containing the stable liturgical key, selected reference,
   response, display order, source-record ID, and source date for provenance.

The existing source-pack model will gain the temporal fields needed for stable
matching. Its exact-date lookup API will be removed from production resolution.

## Generation and reconciliation

For every imported official source record:

1. Resolve the source date through the application's calendar and all available
   reading sets.
2. Match each extracted psalm choice to exactly one temporal, celebration, or
   Mass-form set using reference and response evidence.
3. Assign the stable key from that set and preserve the original source date only
   as provenance.
4. Deduplicate repeated text without deduplicating distinct usages.
5. Fail generation if a choice is unmatched or matches multiple incompatible
   sets.

The currently available official corpus can establish only the cycles and
propers it actually contains. It must not be projected onto unsupported cycles.

## Runtime flow

The resolver passes an explicit usage context whenever it constructs a set:

- primary calendar celebration;
- weekday/temporal set;
- optional memorial proper;
- vigil or another named Mass form;
- special-period set such as Easter Vigil.

The Nigerian usage resolver returns only choices matching that context, sorted
by their reviewed priority. The first result replaces the set's primary psalm;
remaining results become alternatives within that same set. It never imports a
psalm merely because another reading set shared its source date.

After selection, the text renderer tries the user's chosen psalm edition,
territory text, Bible-aligned text, and RSVCE fallback in that order. Every
fallback must preserve the selected normalized reference and response.

## Compatibility and failure behavior

- Non-Nigerian regions continue through existing resolution unchanged.
- An unsupported Nigerian liturgical key retains the existing reviewed
  standard/memorial selection; no date-based guess is allowed.
- Missing selected-edition text falls back visibly without changing selection.
- Source-pack parse or reconciliation errors fail tests/build generation rather
  than silently publishing mixed reading sets.

## Verification

Test-first coverage will prove:

- the existing date-based implementation fails a recurrence test;
- a temporal usage recurs in another year with the same liturgical key;
- it does not recur into a different Sunday or weekday cycle;
- a transferred feast retains its proper;
- weekday and optional memorial psalms remain in separate reading sets;
- vigils and other Mass forms remain distinct;
- every imported official choice maps to exactly one stable usage;
- every usage renders through every installed edition or its declared fallback;
- proper choices display before temporal and alternate choices;
- non-Nigerian resolution is unchanged;
- full focused, static-analysis, serialized-suite, and diff checks pass before
  any commit or push.
