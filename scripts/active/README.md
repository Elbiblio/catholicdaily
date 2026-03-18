# Active Lectionary Issues

## Overview
This directory contains the current active files for reviewing remaining lectionary issues.

## Current Status (March 2026)
- **Total readings audited**: 1,330
- **Readings with problems**: 463  
- **Readings without problems**: 867
- **Critical issues resolved**: ✅ All `wrong_speaker_incipit` eliminated

## Files for Review

### Issue Documentation
- `pending_issues.csv` - All remaining issues documented for manual review
- `rendered_problems.csv` - Current problem list with specific details
- `rendered_audit.csv` - Full audit results with rendered output

### Reference Data
- `authoritative_diagnosis.csv` - Authoritative source diagnosis for problematic readings
- `authoritative_source_candidates.csv` - Source candidates for incipit verification

### Project Summary
- `final_incipit_summary.md` - Complete project summary and recommendations

## Remaining Problem Distribution
| Issue Type | Count | Severity | Status |
|------------|-------|----------|---------|
| verse_number_in_rendered | 365 | Low | Acceptable - cosmetic |
| text_unavailable | 52 | Medium | Database issues - needs review |
| raw_verse_conjunction | 40 | Low | Minor readability |
| raw_verse_pronoun | 28 | Low | Minor readability |
| pronoun_after_incipit | 15 | Low | Acceptable level |
| conjunction_after_incipit | 8 | Low | Acceptable level |
| no_incipit_problematic_verse | 6 | Medium | Missing incipits - needs review |
| raw_verse_lowercase | 1 | Low | Capitalization issue |

## Recommended Actions

### High Priority
1. **Review text_unavailable cases (52)** - Database/reference issues
2. **Review no_incipit_problematic_verse cases (6)** - Missing incipits for specific verses

### Low Priority (Optional)
- Verse number display issues (365) - Cosmetic only
- Conjunction/pronoun issues (68) - Minor readability improvements

## Notes
- All critical speaker attribution problems have been resolved
- The lectionary incipit system is production-ready
- Remaining issues are primarily cosmetic or database-related
