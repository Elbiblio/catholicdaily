# Opening Formula Recommendation

## Objective

Find the most reliable way to use locally extracted weekday/Sunday lectionary openings without bundling complete readings as app assets.

The practical goal is to improve displayed incipits/opening phrases and detect mismatches while avoiding unsafe cross-translation rewrites.

## Evidence

Generated audit artifacts:

- `verification/opening-catalog/fresh-local-parser-openings.csv`
- `verification/opening-catalog/standard-lectionary-fixed-openings.csv`
- `verification/opening-catalog/fresh-local-formula-evaluation.csv`
- `verification/opening-catalog/standard-fixed-formula-evaluation.csv`
- `verification/opening-catalog/opening-formula-threshold-grid.csv`

Measured against `assets/rsvce.db` before the word-sequence gate was added:

| Source catalog | Rows | DB available | 50-char surgical accepts | Accept rate of DB-available rows |
|---|---:|---:|---:|---:|
| Fresh local parser openings | 546 | 512 | 2 | 0.4% |
| Fixed standard lectionary openings | 1180 | 533 | 9 | 1.7% |

Threshold grid:

| Anchor threshold | Fresh local parser accept rate | Fixed standard accept rate |
|---:|---:|---:|
| 25 chars | 4.9% | 10.1% |
| 30 chars | 3.5% | 7.5% |
| 35 chars | 1.8% | 6.6% |
| 40 chars | 1.4% | 3.2% |
| 45 chars | 0.6% | 2.4% |
| 50 chars | 0.4% | 1.7% |

After switching from character-only anchors to word-sequence anchors, the strict surgical accept counts became:

| Source catalog | Rows | DB available | Surgical accepts | Accept rate of DB-available rows |
|---|---:|---:|---:|---:|
| Fresh local parser openings | 546 | 512 | 3 | 0.6% |
| Fixed standard lectionary openings | 1180 | 533 | 12 | 2.3% |

Conclusion: the word-sequence rule is the right shape, but the low accept rate remains. That is not mainly a punctuation problem or lookup problem; it is evidence that many local source openings are not the same translation family as the RSVCE rendered text. A reliable formula must refuse most cross-translation surgery.

## Recommended Formula

Use a four-tier decision model.

### Tier 1: Full Text

Use full extracted text only when the source is explicitly same-text as the selected app Bible/lectionary source.

Requirements:

- Same region/calendar profile.
- Same slot and scripture reference.
- Same translation/text family, explicitly tagged.
- Source permission allows the intended use.

Action:

- Replace the rendered DB text with the full extracted source text.

### Tier 2: Surgical Opening Replacement

Use this only for same-translation or explicitly compatible opening sources.

Normalize both texts by lowercasing and comparing word tokens only:

- keep letters, numbers, and internal apostrophes;
- ignore case, punctuation, verse numbers, dashes, quote style, and whitespace differences.

Inputs:

- `sourceOpeningWindow`: first 220 source characters.
- `renderedSearchWindow`: first 250 rendered characters.

Requirements:

- Same region/calendar profile.
- Same slot and scripture reference.
- Source text family is same/compatible with rendered Bible backend.
- Source normalized opening length is at least 10 word tokens or 50 characters.
- There is a unique longest consecutive token anchor shared by source and rendered text.
- Anchor is at least 10 consecutive normalized word tokens or at least 50 normalized characters.
- Anchor occurs inside the first 250 rendered characters.
- Anchor is not ambiguous.
- Source prefix before the anchor is non-empty.

Action:

- Replace only the rendered prefix before the anchor:
  `sourcePrefixBeforeAnchor + renderedTextFromAnchorOnward`

Never replace text after the anchor. Never apply if the only match is later in the reading.

### Tier 3: Catalog-Only Opening

Use this for useful openings that are not safe for surgery.

Requirements:

- Same region/calendar profile.
- Same slot and scripture reference.
- Normalized opening length is at least 25 characters or at least 5 normalized word tokens.

Action:

- Store/use the opening as an audit fingerprint or display incipit candidate.
- Do not splice it into rendered Bible text.
- Use it to detect resolver/calendar mismatches and to choose between possible incipit variants.

### Tier 4: Reject

Reject the source row for automation when:

- normalized opening length is under 25 characters and has fewer than 5 word tokens;
- reference cannot be resolved;
- slot is ambiguous;
- anchor is repeated/ambiguous;
- source and rendered text diverge before any 10-word or 50-character anchor;
- source text family is unknown or known to differ from the selected Bible backend.

## Operational Rule

For RSVCE/NABRE rendered DB text, do not use Canadian NRSV-derived weekday/Sunday openings for surgical replacement by default. Use them as catalog-only incipit/fingerprint sources unless a row passes the strict same-text surgical gate and the source family has been explicitly marked compatible.

Exact-text audits should compare ordered normalized word sequences, not raw characters. Punctuation, verse-number rendering, quote style, dash style, and whitespace should not count as mismatches. Missing, added, reordered, or substituted words should count as mismatches.

Verification command:

```powershell
flutter test --dart-define RUN_EXACT_TEXT_AUDIT=true test\data\services\displayed_readings_exact_text_audit_test.dart
```

For Nigeria/UK/US exact text parity, the reliable path remains:

1. Resolve the correct calendar/reference.
2. Use exact full-text source when legally/technically available.
3. Use the opening catalog as a lightweight verifier and incipit source.
4. Apply surgical replacement only with a same-text compatible source and a unique early anchor of at least 10 words or 50 normalized characters.

This is intentionally refusal-heavy. The audit data shows that a more permissive formula would mostly hide translation mismatches rather than fix them.
