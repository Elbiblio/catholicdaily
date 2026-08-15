# Liturgical Reading Choices Integrity Design

## Goal

Ensure every supported liturgical day displays the correct celebration readings first while keeping every legitimate reading choice easy to access. Eliminate mismatches caused by parallel feast, memorial, weekday, and alternative-reading catalogs.

## Confirmed Failure

The primary `CsvReadingsResolverService` resolves the correct Mass-during-the-day references for the Assumption, but `AlternateReadingsService` independently rebuilds choices from `OptionalMemorialService._properReadingsMap`. It always prepends a purported ferial set and does not use the resolved liturgical rank or regional transfer. The two paths can therefore disagree about which celebration is primary, which alternatives belong to a slot, and which readings are merely weekday options.

`memorial_feasts.csv` and the hand-written proper-reading map also duplicate overlapping data. Several CSV rows contain values in the wrong semantic column, which the current narrow corruption test does not detect.

## Authoritative Rules

- The resolved regional calendar determines the celebration, date, rank, and transfer before readings are selected.
- Solemnities have three assigned readings and those readings are followed strictly (GIRM 357).
- Feasts have their assigned readings (GIRM 357).
- Memorials normally retain weekday readings unless proper or particularized readings are assigned (GIRM 357â€“358).
- Legitimate choices remain accessible, as requested, but the resolved celebration's authorized set is always first and visually identified as the primary set.
- Alternative forms of a reading belong to the same liturgical slot. They are not standalone full reading sets and must never shift into another slot.

Primary rule source: <https://www.usccb.org/prayer-and-worship/the-mass/general-instruction-of-the-roman-missal/girm-chapter-7>

## Assumption Acceptance Fixture

For the Mass during the Day, the primary references are:

- Revelation 11:19a; 12:1â€“6a, 10ab
- Psalm 45:10, 11, 12, 16
- 1 Corinthians 15:20â€“27
- Luke 1:39â€“56

The Vigil set remains separately accessible and labeled. The daytime set is primary on the feast date unless an explicit Vigil context is selected. Source: <https://bible.usccb.org/bible/readings/081526-Day>.

## Architecture

### Resolve the Day Once

Introduce one reading-choice resolver that consumes the already resolved `LiturgicalDay`, region, date, and lectionary cycles. UI code must not independently infer precedence from fixed-date optional celebrations.

### One Canonical Choice Model

Represent the result as ordered reading sets:

- stable set id;
- display label;
- choice kind (`celebration`, `vigil`, `weekday`, `common`, or other authorized option);
- whether it is primary;
- celebration title and rank;
- ordered readings with alternatives grouped by slot;
- provenance/source classification.

The first set is always the resolved celebration's accurate set. Additional legitimate sets follow with explicit labels such as `Vigil Mass`, `Weekday readings`, or the relevant memorial/common.

### Eliminate Parallel Construction

`AlternateReadingsService` will orchestrate canonical resolver results rather than reconstructing readings from a second hand-written table. `PremiumBrowseScreen` will consume the ordered sets directly instead of loading one service for the page and another for celebration chips.

`OptionalMemorialService` may continue to describe calendar choices during migration, but it will not be an independent authority for scripture references. Proper reading references will come from the same catalog used by `CsvReadingsResolverService` or from an explicitly reviewed override record.

### Catalog Semantics

Each catalog field has one meaning:

- primary first reading;
- alternate first reading for the same slot;
- responsorial psalm and response;
- second reading where the rank requires it;
- primary Gospel;
- alternate/shorter Gospel for the same slot;
- Gospel acclamation.

Rows that contain response prose, incipits, or a different slot's reference in the wrong field fail validation. A corrupt row is never silently displayed or shifted heuristically.

### Regional Transfers

Lookup keys derive from the resolved celebration, not just month/day. Thus the Assumption follows August 15 in Nigeria and regions that retain that date, and the transferred Sunday in regions whose calendar transfers it. The same reading set follows the resolved celebration.

## Ordering Rules

1. Resolved solemnity or feast proper set.
2. Its Vigil or other officially assigned full-form set, when one exists.
3. Other authorized full sets for that celebration.
4. Weekday set, retained for easy reference but labeled non-primary where it is not the liturgical set of the day.
5. Optional memorial/common sets valid for the date.

For memorials, an assigned proper or particularized set is first; otherwise the weekday set is first and the memorial/common choices follow. Duplicate sets are collapsed by normalized slot references while preserving distinct labels only when the liturgical meaning differs.

## Safety and Accuracy Controls

- Do not scrape or commit copyrighted full lectionary text. Store and test references, short labels, and existing licensed/local Bible hydration only.
- Use official conference/Holy See sources for exact assignments and rank rules.
- Keep source-specific regional assignments separate; do not apply a US-only proper to every region without evidence.
- A missing or unverified choice is reported by the audit and omitted from production rather than guessed.
- Every production override must have an exact regression fixture and source note.

## Testing

Start with RED tests proving the current defect:

- Nigeria 2026-08-15 returns Assumption Day first with the four exact references.
- England/Wales and Brazil 2026 transfers return the same feast set on their resolved date.
- Assumption exposes Vigil and weekday sets after the feast set, never before it.
- A feast cannot be replaced by a fixed-date memorial or ferial default.
- Alternatives remain attached to their correct slot.
- All memorial CSV rows pass semantic reference validation.
- Every celebration choice produced for a multi-year, multi-region matrix has a complete rank-appropriate primary set.
- UI tests prove the first visible cards use the primary celebration set and that other choices remain reachable.

Run focused resolver/UI tests, full calendar and Nigeria audits, analyzer, the serialized full Flutter suite, and representative emulator checks before release.

## Migration and Rollback

Migrate incrementally behind tests: add the canonical choice model, route the screen through it, then remove or quarantine duplicated reference data. No destructive data conversion is required. If a catalog cohort cannot be verified in this release, retain its weekday choice and omit the questionable proper choice while recording it in an audit report.

## Success Criteria

- The Assumption displays its correct feast readings first today.
- All supported solemnities, feasts, and memorials have deterministic, rank-aware ordered choices.
- Every legitimate reading choice remains accessible and accurately labeled.
- There is no second UI-only scripture-reference authority.
- Structural and source-backed exhaustive audits pass across supported regions and multiple liturgical years.
