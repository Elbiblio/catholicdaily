"""
Extract Sunday reading references from catholic-sunday-readings.pdf text.
Produces a structured list of: season, week, cycle, first_reading, second_reading, gospel
"""
import re
import json
import os

txt_path = os.path.join(os.path.dirname(__file__), 'sunday_readings_full.txt')
out_path = os.path.join(os.path.dirname(__file__), 'sunday_references_extracted.json')

with open(txt_path, 'r', encoding='utf-8') as f:
    text = f.read()

# Split by page markers
pages = re.split(r'--- PAGE \d+ ---\n', text)

ORDINAL_MAP = {
    '1ST': '1', '2ND': '2', '3RD': '3', '4TH': '4', '5TH': '5',
    '6TH': '6', '7TH': '7', '8TH': '8', '9TH': '9', '10TH': '10',
    '11TH': '11', '12TH': '12', '13TH': '13', '14TH': '14', '15TH': '15',
    '16TH': '16', '17TH': '17', '18TH': '18', '19TH': '19', '20TH': '20',
    '21ST': '21', '22ND': '22', '23RD': '23', '24TH': '24', '25TH': '25',
    '26TH': '26', '27TH': '27', '28TH': '28', '29TH': '29', '30TH': '30',
    '31ST': '31', '32ND': '32', '33RD': '33', '34TH': '34',
    'FIRST': '1', 'SECOND': '2', 'THIRD': '3', 'FOURTH': '4', 'FIFTH': '5',
}

# Book abbreviation normalization
BOOK_EXPAND = {
    'Is': 'Isa', 'Jer': 'Jer', 'Ez': 'Ezek', 'Dn': 'Dan', 'Hos': 'Hos',
    'Jl': 'Joel', 'Am': 'Amos', 'Ob': 'Obad', 'Jon': 'Jon', 'Mi': 'Mic',
    'Na': 'Nah', 'Hb': 'Hab', 'Zep': 'Zeph', 'Hg': 'Hag', 'Zec': 'Zech',
    'Mal': 'Mal', 'Gn': 'Gen', 'Ex': 'Exod', 'Lv': 'Lev', 'Nm': 'Num',
    'Dt': 'Deut', 'Jos': 'Josh', 'Jgs': 'Judg', 'Ru': 'Ruth',
    '1 Sm': '1 Sam', '2 Sm': '2 Sam', '1 Kgs': '1 Kgs', '2 Kgs': '2 Kgs',
    '1 Chr': '1 Chr', '2 Chr': '2 Chr', 'Ezr': 'Ezra', 'Neh': 'Neh',
    'Tb': 'Tob', 'Jdt': 'Jdt', 'Est': 'Esth', '1 Mc': '1 Macc', '2 Mc': '2 Macc',
    'Jb': 'Job', 'Ps': 'Ps', 'Prv': 'Prov', 'Eccl': 'Eccl', 'Sg': 'Song',
    'Wis': 'Wis', 'Sir': 'Sir', 'Bar': 'Bar', 'Lam': 'Lam',
    'Mt': 'Matt', 'Mk': 'Mark', 'Lk': 'Luke', 'Jn': 'John',
    'Acts': 'Acts', 'Rom': 'Rom', '1 Cor': '1 Cor', '2 Cor': '2 Cor',
    'Gal': 'Gal', 'Eph': 'Eph', 'Phil': 'Phil', 'Col': 'Col',
    '1 Thes': '1 Thess', '2 Thes': '2 Thess', '1 Tm': '1 Tim', '2 Tm': '2 Tim',
    'Ti': 'Titus', 'Phlm': 'Phlm', 'Heb': 'Heb', 'Jas': 'Jas',
    '1 Pt': '1 Pet', '2 Pt': '2 Pet', '1 Jn': '1 John', '2 Jn': '2 John',
    '3 Jn': '3 John', 'Jude': 'Jude', 'Rv': 'Rev',
}

# Title pattern
RE_TITLE = re.compile(
    r'(?:CATHOLIC SUNDAY READINGS\s+)?'
    r'(\d+(?:ST|ND|RD|TH)|FIRST|SECOND|THIRD|FOURTH|FIFTH)?\s*'
    r'(?:SUNDAY\s+(?:OF|IN|AFTER)\s+)?'
    r'(ADVENT|LENT|EASTER|ORDINARY\s+TIME|CHRISTMAS|PENTECOST)'
    r'[\s—\-]+'
    r'([ABC](?:\s*/\s*[ABC])*)',
    re.IGNORECASE
)

# Special titles
RE_SPECIAL = re.compile(
    r'(ASH\s+WEDNESDAY|PALM\s+(?:\(PASSION\)\s+)?SUNDAY|'
    r'GOOD\s+FRIDAY|HOLY\s+THURSDAY|EASTER\s+VIGIL|EASTER\s+SUNDAY|'
    r'CHRISTMAS\s+\((?:VIGIL|MIDNIGHT|DAWN|DAY)\)|'
    r'HOLY\s+FAMILY|EPIPHANY|BAPTISM\s+OF\s+THE\s+LORD|'
    r'HOLY\s+TRINITY|CORPUS\s+CHRISTI|SACRED\s+HEART|'
    r'ASCENSION|PENTECOST\s+SUNDAY|'
    r'MARY,?\s+MOTHER\s+OF\s+GOD|'
    r'CHRIST\s+THE\s+KING|'
    r'ALL\s+SAINTS|ALL\s+SOULS)'
    r'[\s—\-]*([ABC](?:\s*/\s*[ABC])*)?',
    re.IGNORECASE
)

# Reading reference patterns
RE_FIRST = re.compile(r'FIRST\s+READING\s*\(([^)]+)\)', re.IGNORECASE)
RE_SECOND = re.compile(r'SECOND\s+READING\s*\(([^)]+)\)', re.IGNORECASE)
RE_GOSPEL_REF = re.compile(r'GOSPEL\s*\(([^)]+)\)', re.IGNORECASE)
RE_PSALM_REF = re.compile(r'RESPONSORIAL\s+PSALM\s*\(([^)]+)\)', re.IGNORECASE)
RE_ALLELUIA_REF = re.compile(r'ALLELUIA\s*\(([^)]+)\)', re.IGNORECASE)
RE_GOSPEL_ACCL_REF = re.compile(r'GOSPEL\s+ACCLAMATION\s*\(([^)]+)\)', re.IGNORECASE)

results = []
current_season = None
current_week = None
current_cycle = None
current_special = None

for page_text in pages:
    if not page_text.strip():
        continue

    lines = page_text.strip().split('\n')
    full_page = ' '.join(lines)

    # Try to detect title
    title_match = RE_TITLE.search(full_page[:300])
    special_match = RE_SPECIAL.search(full_page[:300])

    if title_match:
        ordinal = title_match.group(1)
        season_raw = title_match.group(2).strip()
        cycle = title_match.group(3).strip().upper()

        week = ORDINAL_MAP.get(ordinal.upper(), ordinal) if ordinal else ''

        season_map = {
            'ADVENT': 'Advent', 'LENT': 'Lent', 'EASTER': 'Easter',
            'ORDINARY TIME': 'Ordinary Time', 'CHRISTMAS': 'Christmas',
            'PENTECOST': 'Easter',
        }
        season = season_map.get(season_raw.upper(), season_raw)

        current_season = season
        current_week = week
        current_cycle = cycle
        current_special = None

    elif special_match:
        current_special = special_match.group(1).strip()
        cycle_raw = special_match.group(2)
        current_cycle = cycle_raw.strip().upper() if cycle_raw else 'ABC'

    # Extract references
    first_reading = None
    second_reading = None
    gospel = None
    psalm = None
    alleluia = None

    m = RE_FIRST.search(full_page)
    if m:
        first_reading = m.group(1).strip()

    m = RE_SECOND.search(full_page)
    if m:
        second_reading = m.group(1).strip()

    m = RE_GOSPEL_REF.search(full_page)
    if m:
        gospel = m.group(1).strip()

    m = RE_PSALM_REF.search(full_page)
    if m:
        psalm = m.group(1).strip()

    m = RE_ALLELUIA_REF.search(full_page)
    if m:
        alleluia = m.group(1).strip()
    else:
        m = RE_GOSPEL_ACCL_REF.search(full_page)
        if m:
            alleluia = m.group(1).strip()

    # Only record if we have at least a first reading
    if first_reading and (current_season or current_special):
        entry = {
            'season': current_season or '',
            'week': current_week or '',
            'cycle': current_cycle or 'ABC',
            'special': current_special or '',
            'first_reading': first_reading,
            'second_reading': second_reading or '',
            'psalm': psalm or '',
            'alleluia': alleluia or '',
            'gospel': gospel or '',
        }
        results.append(entry)

# Write JSON for inspection
with open(out_path, 'w', encoding='utf-8') as f:
    json.dump(results, f, indent=2, ensure_ascii=False)

print(f"Extracted {len(results)} Sunday reading sets")

# Summary
seasons = {}
for r in results:
    key = r['season'] or r['special']
    seasons[key] = seasons.get(key, 0) + 1
print("\nBy season:")
for s, count in sorted(seasons.items()):
    print(f"  {s}: {count}")

# Check for missing references
missing_second = sum(1 for r in results if not r['second_reading'])
missing_gospel = sum(1 for r in results if not r['gospel'])
print(f"\nMissing second reading: {missing_second}")
print(f"Missing gospel: {missing_gospel}")
