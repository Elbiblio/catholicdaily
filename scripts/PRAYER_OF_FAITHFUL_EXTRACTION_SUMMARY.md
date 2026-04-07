# Prayer of the Faithful Extraction Summary

## Extraction Complete

Successfully extracted Prayer of the Faithful content from the 1967 Archive.org source and Spanish CPL documents.

## Files Created

### 1967 Archive.org Source
1. **scripts/prayer_of_faithful_1967.pdf** (61MB)
   - Original PDF from Archive.org
   - Complete book with all Sundays and Holydays

2. **scripts/prayer_of_faithful_1967.epub** (4MB)
   - EPUB version from Archive.org
   - Used for text extraction

3. **scripts/prayer_of_faithful_1967_extracted.txt**
   - Raw text extracted from EPUB
   - 114 pages of content

4. **scripts/prayer_of_faithful_1967_comprehensive.csv**
   - 100 entries parsed from EPUB (intermediate)
   - Includes fragmentary entries

5. **scripts/prayer_of_faithful_1967_cleaned.csv** (FINAL)
   - **86 entries** cleaned and consolidated
   - Structure: `page_number,occasion,petitions`
   - All fragmentary entries removed
   - Appendix (pages 102-109) consolidated into single entry

6. **scripts/prayer_of_faithful_mapped.csv** (MAPPED TO CURRENT CALENDAR)
   - **86 entries** mapped to current Roman liturgical calendar
   - Structure: `season,week,day,occasion_1967,season_mapped,week_mapped,day_mapped,cycle_applicability,notes,petitions,page_number`
   - **63 entries** mapped to current calendar (Advent, Christmas, Lent, Easter, Ordinary Time, Major Feasts)
   - **3 entries** marked as obsolete (pre-Lent Sundays removed from current calendar)
   - **18 entries** special occasions (sacraments, devotions, community events)
   - **2 entries** appendix/reference materials

### Spanish CPL Source
1. **scripts/cpl_prayer_faithful_2026-04-12.doc** (downloaded)
2. **scripts/cpl_prayer_faithful_2026-04-19.doc** (downloaded)
3. **scripts/cpl_prayer_faithful_2026-04-26.doc** (downloaded)
4. **scripts/cpl_prayer_faithful_2026-04-12.txt** (extracted)
5. **scripts/cpl_prayer_faithful_2026-04-19.txt** (extracted)
6. **scripts/cpl_prayer_faithful_2026-04-26.txt** (extracted)
7. **scripts/cpl_prayer_faithful_spanish.csv** (FINAL)
   - **3 entries** parsed from Spanish Word documents
   - Structure: `date,liturgical_reference,year,response,petitions,concluding_prayer`
   - Content: 2nd, 3rd, 4th Sundays of Easter Year A (April 2026)
   - Language: Spanish

## Content Coverage

### Liturgical Calendar (Sundays & Holydays) - 63 entries
- **Advent:** 4 Sundays (1st, 2nd, 3rd, 4th)
- **Christmas Season:** Christmas Day, Octave of Nativity, Most Holy Name of Jesus, Epiphany, Holy Family, Sunday within Octave of Christmas
- **Epiphany Season:** 6 Sundays after Epiphany
- **Pre-Lent:** Septuagesima, Sexagesima, Quinquagesima Sundays
- **Lent:** 4 Sundays in Lent
- **Passiontide:** 2 Sundays (1st Sunday in Passiontide, Palm Sunday)
- **Easter Season:** Easter Sunday, Low Sunday, 5 Sundays after Easter
- **Ascension:** Ascension of Our Lord, Sunday after Ascension
- **Pentecost Season:** Pentecost/Whit Sunday, Trinity Sunday, Corpus Christi, Most Sacred Heart of Jesus
- **Ordinary Time:** 23 Sundays after Pentecost (2nd through 24th and Last)
- **Major Feasts:** SS. Peter & Paul, Kingship of Our Lord Jesus Christ, Assumption of Our Lady, All Saints, All Souls' Day, Feasts of Our Lady, Feasts of Saints, Dedication of a Church

### Special Occasions - 22 entries
- **Sacraments:** Confirmations (2 variants), Baptisms, First Communions, Ordinations
- **Marriage:** Nuptial Mass, Weddings
- **Funerals:** Funerals, Cenotaph Services
- **Devotional:** Benediction (Holy Hour), Bible Vigils, May Processions, Pilgrimages
- **Community:** Youth Rallies, Education Days, Missions, Paternal Feasts, Any Saint's Day

### Appendix - 1 entry
- Categorized petitions (8 pages consolidated) for:
  - Baptism, Benefactors, Bishops, Church, Citizens, Civil Strife
  - Communion, Confession, Confirmation, Crops, Crosses, Dead, Doctors, Dying
  - Elections, Enemies, Exiles, Family, Fellow Christians, Fidelity, Forces
  - Government, Guidance, Happy Death, Holy Spirit, Hungry, Industrial Strife
  - Industries, Interior Peace, Jubilees, Lent, Lonely, Mass, Mourners
  - Needy, Nurses, Organizations, Parish, People of God, Pope, Priests & Religious
  - Prisoners, Religious, Rulers, Sacraments, Schools, Sick, Sinners
  - Sovereign, Strife, Suffering, Travellers, Unity, Universities, Vocations
  - Wealth, Weather, Workers, Younger Nations, Youth

## CSV Structure

```
page_number,occasion,petitions
10,THE FIRST SUNDAY OF ADVENT,"Petition 1 | Petition 2 | Petition 3"
102-109,APPENDIX - Categorized Petitions,"BAPTISM petition | BENEFACTORS petition | ..."
```

## Calendar Mapping to Current Roman Calendar

The 1967 source uses the pre-1970 Roman calendar which included:
- **Pre-Lent Sundays:** Septuagesima, Sexagesima, Quinquagesima (3 Sundays before Lent)
- **Sundays after Pentecost:** Instead of "Sundays in Ordinary Time"

### Mapping Results

**Mapped to Current Calendar (63 entries):**
- All Advent, Christmas, Lent, Easter seasons properly mapped
- "Sundays after Pentecost" → "Ordinary Time" (weeks 4-34)
- Major feasts mapped to current calendar (Trinity, Corpus Christi, Sacred Heart, Christ the King)
- Cycle applicability: marked as "ALL" since 1967 source is cycle-independent (not differentiated by Years A, B, C)

**Obsolete Entries (3 entries):**
- Septuagesima Sunday (removed from current calendar)
- Sexagesima Sunday (removed from current calendar)
- Quinquagesima Sunday (removed from current calendar)

**Special Occasions (18 entries):**
- Sacraments: Confirmations (2), Baptisms, First Communions, Ordinations, Weddings, Funerals
- Devotional: Benediction, Bible Vigils, May Processions, Pilgrimages
- Community: Youth Rallies, Education Days, Missions, Paternal Feasts

**Appendix (2 entries):**
- Categorized petition templates
- Reference materials

### Notes on Calendar Differences

The 1967 collection was created before the 1969/1970 liturgical calendar reform. Key differences:
- Pre-Lent Sundays no longer exist in current Roman calendar
- "Sundays after Pentecost" renamed to "Sundays in Ordinary Time"
- Some feast days moved or renamed (e.g., "Kingship of Our Lord" → "Christ the King")
- The 1967 source is cycle-independent, while current calendar uses 3-year cycle (A, B, C) for Sundays

## Extraction Quality

- **OCR Errors Corrected:** Fixed "TEE INVITATION" and "TELE INVITATION" artifacts
- **Fragmentary Entries Removed:** Removed continuation pages (75-78, 84-87)
- **Appendix Consolidated:** 8 separate appendix pages merged into single entry
- **Title Extraction:** Clean occasion titles separated from petition content
- **Petitions:** Individual petitions separated by " | " delimiter

## Issues to Address

1. **Copyright Verification:** Need to verify the 1967 copyright status before production use
2. **Petition Cleaning:** Some petitions still include response text ("Lord, graciously hear us") that should be removed
3. **Spanish Sources License:** Need to check CPL terms of use for Spanish prayers
4. **Cycle Differentiation:** 1967 source is cycle-independent; may need to create cycle-specific variations for Years A, B, C
5. **Integration with Lectionary:** Map prayer entries to specific dates in `standard_lectionary_complete.csv`

## Next Steps

1. ~~Clean petition text (remove "Lord, hear us" responses)~~ - Partially done, some artifacts remain
2. ~~Verify copyright status of 1967 publication~~ - Not yet done
3. ~~Extract content from CPL Spanish Word documents~~ - **COMPLETED**
4. ~~Map to current liturgical calendar structure~~ - **COMPLETED**
5. Create integration structure to link with `standard_lectionary_complete.csv`
6. Consider creating a unified `prayer_of_faithful.csv` with columns:
   - `date` (from lectionary)
   - `season` (from mapping)
   - `week` (from mapping)
   - `day` (from mapping)
   - `cycle` (A, B, C, or ALL)
   - `occasion`
   - `petitions`
   - `source` (1967 Archive.org, CPL, etc.)
   - `language` (English, Spanish, etc.)

## Potential Integration Strategy

### Option 1: Add to Lectionary CSV
Add `prayer_of_faithful` field to `standard_lectionary_complete.csv` with pipe-separated petitions

### Option 2: Separate Prayer CSV
Create `prayer_of_faithful.csv` with structure matching lectionary:
- Link via `date` or liturgical reference (season, week, day, cycle)
- Support multiple languages
- Support multiple sources (1967 Archive.org, CPL, etc.)

### Option 3: Database Integration
Add prayer table to existing database structure with foreign key to lectionary entries
