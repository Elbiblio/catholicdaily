import csv
import json
import os
import re
from collections import OrderedDict

BASE = r'c:\dev\catholicdaily-flutter'
SCRIPTS = os.path.join(BASE, 'scripts')
PSALM_CSV = os.path.join(BASE, 'lectionary_psalms.csv')
SUNDAY_JSON = os.path.join(SCRIPTS, 'sunday_references_extracted.json')
STANDARD_BACKFILL_JSON = os.path.join(SCRIPTS, 'standard_backfill_refs.json')
WEEKDAY_FILES = [
    os.path.join(SCRIPTS, 'weekday_a_full.txt'),
    os.path.join(SCRIPTS, 'weekday_b_full.txt'),
]
OUT_CSV = os.path.join(BASE, 'standard_lectionary_complete.csv')

WEEK_WORDS = {
    'FIRST':'1','SECOND':'2','THIRD':'3','FOURTH':'4','FIFTH':'5','SIXTH':'6','SEVENTH':'7','EIGHTH':'8','NINTH':'9','TENTH':'10',
    'ELEVENTH':'11','TWELFTH':'12','THIRTEENTH':'13','FOURTEENTH':'14','FIFTEENTH':'15','SIXTEENTH':'16','SEVENTEENTH':'17','EIGHTEENTH':'18',
    'NINETEENTH':'19','TWENTIETH':'20','TWENTY-FIRST':'21','TWENTY-SECOND':'22','TWENTY-THIRD':'23','TWENTY-FOURTH':'24','TWENTY-FIFTH':'25',
    'TWENTY-SIXTH':'26','TWENTY-SEVENTH':'27','TWENTY-EIGHTH':'28','TWENTY-NINTH':'29','THIRTIETH':'30','THIRTY-FIRST':'31','THIRTY-SECOND':'32',
    'THIRTY-THIRD':'33','THIRTY-FOURTH':'34',
}
WEEK_WORD_PAT = '|'.join(sorted(WEEK_WORDS.keys(), key=len, reverse=True))

RE_OT_FOOTER = re.compile(rf'(\d+)\s+({WEEK_WORD_PAT})\s+WEEK\s+IN\s+ORDINARY\s+TIME\s*[–\-]\s*YEAR\s+(I{{1,2}})', re.IGNORECASE)
RE_LENT_FOOTER = re.compile(rf'(\d+)\s+({WEEK_WORD_PAT})\s+WEEK\s+OF\s+LENT', re.IGNORECASE)
RE_ADVENT_FOOTER = re.compile(rf'(\d+)\s+({WEEK_WORD_PAT})\s+WEEK\s+OF\s+ADVENT', re.IGNORECASE)
RE_EASTER_FOOTER = re.compile(rf'(\d+)\s+({WEEK_WORD_PAT})\s+WEEK\s+OF\s+EASTER', re.IGNORECASE)
RE_WEEK_HEADER = re.compile(rf'({WEEK_WORD_PAT})\s+WEEK\s+(?:OF|IN)\s+(ADVENT|LENT|EASTER|ORDINARY\s+TIME)', re.IGNORECASE)
RE_DAY_HEADER = re.compile(r'^(\d{1,4})\s+(MONDAY|TUESDAY|WEDNESDAY|THURSDAY|FRIDAY|SATURDAY)\s*$')
RE_DATE_HEADER = re.compile(r'^(\d{1,4})\s+(DECEMBER|JANUARY|FEBRUARY|MARCH|APRIL|MAY|JUNE)\s+(\d{1,2})\s*$')
RE_FIRST = re.compile(r'^FIRST\s+READING(?:\s*[–\-]\s*YEAR[S]?\s+[A-Z,\s]+)?\s+(.+)$', re.IGNORECASE)
RE_GOSPEL = re.compile(r'^GO\s*S\s*P\s*E\s*L\s+(.+)$', re.IGNORECASE)

SUNDAY_FIXES = {
    ('Advent', '1', 'A'): {'gospel': 'Matt 24:37-44'},
    ('Advent', '4', 'A'): {'gospel': 'Matt 1:18-24'},
    ('Lent', '2', 'B'): {'gospel': 'Mark 9:2-10'},
    ('Lent', '2', 'C'): {'gospel': 'Luke 9:28b-36'},
    ('Lent', '3', 'A'): {'gospel': 'John 4:5-42'},
    ('Lent', '4', 'A'): {'gospel': 'John 9:1-41'},
    ('Lent', '5', 'C'): {'gospel': 'John 8:1-11'},
    ('Ordinary Time', '4', 'C'): {'gospel': 'Luke 4:21-30'},
}

MANUAL_SUNDAY_REFERENCES = {
    ('Lent', '3', 'B'): {'first_reading': 'Exod 20:1-17', 'second_reading': '1 Cor 1:22-25', 'gospel': 'John 2:13-25'},
    ('Easter', '6', 'A'): {'first_reading': 'Acts 8:5-8, 14-17', 'second_reading': '1 Pet 3:15-18', 'gospel': 'John 14:15-21'},
    ('Easter', '6', 'B'): {'first_reading': 'Acts 10:25-26, 34-35, 44-48', 'second_reading': '1 John 4:7-10', 'gospel': 'John 15:9-17'},
    ('Easter', '6', 'C'): {'first_reading': 'Acts 15:1-2, 22-29', 'second_reading': 'Rev 21:10-14, 22-23', 'gospel': 'John 14:23-29'},
    ('Easter', '7', 'A'): {'first_reading': 'Acts 1:12-14', 'second_reading': '1 Pet 4:13-16', 'gospel': 'John 17:1-11a'},
    ('Easter', '7', 'B'): {'first_reading': 'Acts 1:15-17, 20a, 20c-26', 'second_reading': '1 John 4:11-16', 'gospel': 'John 17:11b-19'},
    ('Easter', '7', 'C'): {'first_reading': 'Acts 7:55-60', 'second_reading': 'Rev 22:12-14, 16-17, 20', 'gospel': 'John 17:20-26'},
    ('Ordinary Time', '27', 'A'): {'first_reading': 'Isa 5:1-7', 'second_reading': 'Phil 4:6-9', 'gospel': 'Matt 21:33-43'},
    ('Ordinary Time', '27', 'B'): {'first_reading': 'Gen 2:18-24', 'second_reading': 'Heb 2:9-11', 'gospel': 'Mark 10:2-16'},
    ('Ordinary Time', '27', 'C'): {'first_reading': 'Hab 1:2-3; 2:2-4', 'second_reading': '2 Tim 1:6-8, 13-14', 'gospel': 'Luke 17:5-10'},
    ('Ordinary Time', '28', 'A'): {'first_reading': 'Isa 25:6-10a', 'second_reading': 'Phil 4:12-14, 19-20', 'gospel': 'Matt 22:1-14'},
    ('Ordinary Time', '28', 'B'): {'first_reading': 'Wis 7:7-11', 'second_reading': 'Heb 4:12-13', 'gospel': 'Mark 10:17-30'},
    ('Ordinary Time', '28', 'C'): {'first_reading': '2 Kgs 5:14-17', 'second_reading': '2 Tim 2:8-13', 'gospel': 'Luke 17:11-19'},
    ('Ordinary Time', '29', 'A'): {'first_reading': 'Isa 45:1, 4-6', 'second_reading': '1 Thess 1:1-5b', 'gospel': 'Matt 22:15-21'},
    ('Ordinary Time', '29', 'B'): {'first_reading': 'Isa 53:10-11', 'second_reading': 'Heb 4:14-16', 'gospel': 'Mark 10:35-45'},
    ('Ordinary Time', '29', 'C'): {'first_reading': 'Exod 17:8-13', 'second_reading': '2 Tim 3:14-4:2', 'gospel': 'Luke 18:1-8'},
    ('Ordinary Time', '30', 'A'): {'first_reading': 'Exod 22:20-26', 'second_reading': '1 Thess 1:5c-10', 'gospel': 'Matt 22:34-40'},
    ('Ordinary Time', '30', 'B'): {'first_reading': 'Jer 31:7-9', 'second_reading': 'Heb 5:1-6', 'gospel': 'Mark 10:46-52'},
    ('Ordinary Time', '30', 'C'): {'first_reading': 'Sir 35:12-14, 16-18', 'second_reading': '2 Tim 4:6-8, 16-18', 'gospel': 'Luke 18:9-14'},
    ('Ordinary Time', '31', 'A'): {'first_reading': 'Mal 1:14b-2:2b, 8-10', 'second_reading': '1 Thess 2:7b-9, 13', 'gospel': 'Matt 23:1-12'},
    ('Ordinary Time', '31', 'B'): {'first_reading': 'Deut 6:2-6', 'second_reading': 'Heb 7:23-28', 'gospel': 'Mark 12:28b-34'},
    ('Ordinary Time', '31', 'C'): {'first_reading': 'Wis 11:22-12:2', 'second_reading': '2 Thess 1:11-2:2', 'gospel': 'Luke 19:1-10'},
    ('Ordinary Time', '32', 'A'): {'first_reading': 'Wis 6:12-16', 'second_reading': '1 Thess 4:13-18', 'gospel': 'Matt 25:1-13'},
    ('Ordinary Time', '32', 'B'): {'first_reading': '1 Kgs 17:10-16', 'second_reading': 'Heb 9:24-28', 'gospel': 'Mark 12:38-44'},
    ('Ordinary Time', '32', 'C'): {'first_reading': '2 Macc 7:1-2, 9-14', 'second_reading': '2 Thess 2:16-3:5', 'gospel': 'Luke 20:27-38'},
    ('Ordinary Time', '33', 'A'): {'first_reading': 'Prov 31:10-13, 19-20, 30-31', 'second_reading': '1 Thess 5:1-6', 'gospel': 'Matt 25:14-30'},
    ('Ordinary Time', '33', 'B'): {'first_reading': 'Dan 12:1-3', 'second_reading': 'Heb 10:11-14, 18', 'gospel': 'Mark 13:24-32'},
    ('Ordinary Time', '33', 'C'): {'first_reading': 'Mal 3:19-20a', 'second_reading': '2 Thess 3:7-12', 'gospel': 'Luke 21:5-19'},
    ('Ordinary Time', '34', 'A'): {'first_reading': 'Ezek 34:11-12, 15-17', 'second_reading': '1 Cor 15:20-26, 28', 'gospel': 'Matt 25:31-46'},
    ('Ordinary Time', '34', 'B'): {'first_reading': 'Dan 7:13-14', 'second_reading': 'Rev 1:5-8', 'gospel': 'John 18:33b-37'},
    ('Ordinary Time', '34', 'C'): {'first_reading': '2 Sam 5:1-3', 'second_reading': 'Col 1:12-20', 'gospel': 'Luke 23:35-43'},
}

MANUAL_WEEKDAY_REFERENCES = {
    ('Advent', 'Dec 17-24', 'December 24', 'I/II', '200', ''): ('2 Samuel 7.1-5, 8-12, 16', 'Luke 1.67-79'),
    ('Advent', '3', 'Friday', 'I/II', '191', ''): ('Isaiah 56.1-3a, 6-8', 'John 5.16-17, 33-36'),
    ('Advent', '1', 'Monday', 'I/II', '175', 'A'): ('Isaiah 4.2-6', 'Matthew 8.5-11, 13'),
    ('Ordinary Time', '6', 'Saturday', 'II', '340', ''): ('James 3.1-10', 'Mark 9.2-13'),
    ('Ordinary Time', '7', 'Saturday', 'II', '346', ''): ('James 5.13-20', 'Mark 10.13-16'),
    ('Ordinary Time', '8', 'Saturday', 'I', '352', ''): ('Sirach 51.12-20', 'Mark 11.27-33'),
    ('Ordinary Time', '8', 'Saturday', 'II', '352', ''): ('Jude 17-25', 'Mark 11.27-33'),
    ('Ordinary Time', '5', 'Friday', 'I', '333', 'ALL'): ('Genesis 3.1-8', 'Mark 7.31-37'),
    ('Ordinary Time', '15', 'Wednesday', 'I', '391', 'ALL'): ('Exodus 3.1-6, 9-12', 'Matthew 11.25-27'),
    ('Ordinary Time', '21', 'Saturday', 'II', '430', 'ALL'): ('1 Corinthians 1.26-31', 'Matthew 25.14-30'),
    ('Ordinary Time', '34', 'Saturday', 'II', '508', 'ALL'): ('Daniel 7.15-27', 'Luke 21.34-36'),
    ('Lent', 'After Ash Wed', 'Ash Wednesday', 'I/II', '219', ''): ('Joel 2:12-18', 'Matt 6:1-18'),
    ('Lent', '1', 'Ash Wednesday', 'I/II', '219', ''): ('Joel 2:12-18', 'Matt 6:1-18'),
    ('Holy Week', '', 'Palm Sunday', '', '', ''): ('Mark 11:1-10', 'Mark 14:1-15:47'),
    ('Holy Week', '', 'Holy Thursday', '', '', ''): ('Exod 12:1-14', 'John 13:1-15'),
    ('Holy Week', '', 'Good Friday', '', '', ''): ('Isa 52:13-53:12', 'John 18:1-19:42'),
    ('Easter', '2', 'Saturday', 'I/II', '272', ''): ('Acts 6.1-7', 'John 6.16-21'),
    ('Easter', '3', 'Saturday', 'I/II', '278', ''): ('Acts 9.31-42', 'John 6.53, 60-69'),
    ('Easter', '4', 'Saturday', 'I/II', '284', ''): ('Acts 13.44-52', 'John 14.7-14'),
    ('Easter', '5', 'Saturday', 'I/II', '290', ''): ('Acts 16.1-10', 'John 15.18-21'),
    ('Easter', '6', 'Saturday', 'I/II', '296', ''): ('Acts 18.23-28', 'John 16.23b-28'),
    ('Easter', '7', 'Saturday', 'I/II', '302', 'ALL'): ('Acts 28.16-20, 30-31', 'John 21.20-25'),
    ('Easter', 'Vigil', 'Easter Vigil - Psalm 1', '', '', ''): ('Genesis 1:1-2:2 or 1:1, 26-31a', 'Matthew 28:1-10 (A); Mark 16:1-7 (B); Luke 24:1-12 (C)'),
    ('Easter', 'Vigil', 'Easter Vigil - Psalm 1 (Alt)', '', '', ''): ('Genesis 1:1-2:2 or 1:1, 26-31a', 'Matthew 28:1-10 (A); Mark 16:1-7 (B); Luke 24:1-12 (C)'),
    ('Easter', 'Vigil', 'Easter Vigil - Psalm 2', '', '', ''): ('Genesis 22:1-18 or 22:1-2, 9a, 10-13, 15-18', 'Matthew 28:1-10 (A); Mark 16:1-7 (B); Luke 24:1-12 (C)'),
    ('Easter', 'Vigil', 'Easter Vigil - Psalm 3', '', '', ''): ('Exodus 14:15-15:1', 'Matthew 28:1-10 (A); Mark 16:1-7 (B); Luke 24:1-12 (C)'),
    ('Easter', 'Vigil', 'Easter Vigil - Psalm 4', '', '', ''): ('Isaiah 54:5-14', 'Matthew 28:1-10 (A); Mark 16:1-7 (B); Luke 24:1-12 (C)'),
    ('Easter', 'Vigil', 'Easter Vigil - Psalm 5', '', '', ''): ('Isaiah 55:1-11', 'Matthew 28:1-10 (A); Mark 16:1-7 (B); Luke 24:1-12 (C)'),
    ('Easter', 'Vigil', 'Easter Vigil - Psalm 5 (Alt)', '', '', ''): ('Isaiah 55:1-11', 'Matthew 28:1-10 (A); Mark 16:1-7 (B); Luke 24:1-12 (C)'),
    ('Easter', 'Vigil', 'Easter Vigil - Psalm 6', '', '', ''): ('Baruch 3:9-15, 32-4:4', 'Matthew 28:1-10 (A); Mark 16:1-7 (B); Luke 24:1-12 (C)'),
    ('Easter', 'Vigil', 'Easter Vigil - Psalm 7', '', '', ''): ('Ezekiel 36:16-17a, 18-28', 'Matthew 28:1-10 (A); Mark 16:1-7 (B); Luke 24:1-12 (C)'),
    ('Easter', 'Vigil', 'Easter Vigil - Alleluia Psalm', '', '', ''): ('Romans 6:3-11', 'Matthew 28:1-10 (A); Mark 16:1-7 (B); Luke 24:1-12 (C)'),
}

BOOK_FIXES = {
    'Is ': 'Isa ', 'Ex ': 'Exod ', 'Mt ': 'Matt ', 'Mk ': 'Mark ', 'Lk ': 'Luke ', 'Jn ': 'John ',
    '1 Thes ': '1 Thess ', '2 Thes ': '2 Thess ', 'Rv ': 'Rev ', '1 Sm ': '1 Sam ', '2 Sm ': '2 Sam ',
    '1 Kgs ': '1 Kgs ', '2 Kgs ': '2 Kgs ', 'Nm ': 'Num ', 'Dt ': 'Deut ', 'Gn ': 'Gen ', 'Lv ': 'Lev ',
    'Jos ': 'Josh ', 'Jgs ': 'Judg ', 'Prv ': 'Prov ', 'Jb ': 'Job ', 'Wis ': 'Wis ', 'Sirach ': 'Sir ',
}

FIELDS = [
    'season', 'week', 'day', 'weekday_cycle', 'sunday_cycle', 'reading_cycle',
    'first_reading', 'second_reading', 'psalm_reference', 'psalm_response',
    'gospel', 'acclamation_ref', 'acclamation_text', 'lectionary_number'
]


def clean_ref(value):
    value = (value or '').strip()
    value = re.sub(r'\s*\+\+\s*$', '', value)
    value = re.sub(r'\s*@\s*$', '', value)
    for old, new in BOOK_FIXES.items():
        if value.startswith(old):
            value = new + value[len(old):]
    value = value.replace(' .', '.').replace(' ,', ',')
    value = re.sub(r'\s{2,}', ' ', value)
    return value.strip()


def parse_first_reading_line(text):
    stripped = text.strip()
    if not stripped.upper().startswith('FIRST READING'):
        return None, None

    remainder = re.sub(r'^FIRST\s+READING', '', stripped, flags=re.IGNORECASE).strip()
    reading_cycle = 'ALL'

    if remainder.startswith('–') or remainder.startswith('-'):
        remainder = remainder[1:].strip()
        cycle_match = re.match(r'^YEAR[S]?\s+([A-Z,\s]+?)\s+(.+)$', remainder, flags=re.IGNORECASE)
        if cycle_match:
            reading_cycle = cycle_match.group(1).strip().replace(' ', '')
            remainder = cycle_match.group(2).strip()

    return reading_cycle, clean_ref(remainder)


def word_to_num(word):
    return WEEK_WORDS.get(word.upper(), word)


def load_psalm_catalog():
    rows = []
    with open(PSALM_CSV, newline='', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows.append({
                'season': row['Season'].strip(),
                'week': row['Week'].strip(),
                'day': row['Day'].strip(),
                'weekday_cycle': row['Weekday Cycle'].strip(),
                'sunday_cycle': row['Sunday Cycle'].strip(),
                'psalm_reference': row['Full Reference'].strip(),
                'psalm_response': row['Refrain Text'].strip(),
                'acclamation_ref': row['Acclamation Ref'].strip(),
                'acclamation_text': row['Acclamation Text'].strip(),
                'lectionary_number': row['Lectionary Number'].strip(),
            })
    return rows


def load_sunday_refs():
    with open(SUNDAY_JSON, encoding='utf-8') as f:
        raw = json.load(f)
    result = OrderedDict()
    ot_next_week = {'A': 6, 'B': 6, 'C': 6}
    for row in raw:
        if row.get('special'):
            continue
        season = row['season'].strip()
        week = row['week'].strip()
        cycle = row['cycle'].strip()
        if not season or not cycle:
            continue
        if season == 'Ordinary Time' and not week:
            week = str(ot_next_week[cycle])
            ot_next_week[cycle] += 1
        elif season == 'Ordinary Time' and week.isdigit():
            ot_next_week[cycle] = max(ot_next_week[cycle], int(week) + 1)
        key = (season, week, cycle)
        current = {
            'first_reading': clean_ref(row.get('first_reading', '')),
            'second_reading': clean_ref(row.get('second_reading', '')),
            'gospel': clean_ref(row.get('gospel', '')),
        }
        if key not in result or sum(bool(current[k]) for k in current) > sum(bool(result[key][k]) for k in result[key]):
            result[key] = current
    for key, fixes in SUNDAY_FIXES.items():
        result.setdefault(key, {'first_reading': '', 'second_reading': '', 'gospel': ''})
        result[key].update(fixes)
    for key, refs in MANUAL_SUNDAY_REFERENCES.items():
        result.setdefault(key, {'first_reading': '', 'second_reading': '', 'gospel': ''})
        result[key].update(refs)
    return result


def load_generated_weekday_backfill():
    if not os.path.exists(STANDARD_BACKFILL_JSON):
        return {}
    with open(STANDARD_BACKFILL_JSON, encoding='utf-8') as f:
        raw = json.load(f)
    refs = {}
    for row in raw:
        key = (
            row.get('season', '').strip(),
            row.get('week', '').strip(),
            row.get('day', '').strip(),
            row.get('weekday_cycle', '').strip(),
            row.get('lectionary_number', '').strip(),
            row.get('reading_cycle', '').strip(),
        )
        refs[key] = (
            clean_ref(row.get('first_reading', '')),
            clean_ref(row.get('gospel', '')),
        )
    return refs


def extract_weekday_refs(path):
    with open(path, encoding='utf-8') as f:
        lines = f.read().splitlines()

    season = week = day = lect_num = year_cycle = ''
    first_reading = gospel = reading_cycle = ''
    refs = {}

    def persist_current():
        if season and week and day and (first_reading or gospel):
            key = (season, week, day, year_cycle, lect_num, reading_cycle)
            refs[key] = (first_reading, gospel)

    for line in lines:
        text = line.strip()
        upper = text.upper()

        m = RE_OT_FOOTER.search(text)
        if m:
            season = 'Ordinary Time'; week = word_to_num(m.group(2)); year_cycle = m.group(3).upper(); continue
        m = RE_LENT_FOOTER.search(text)
        if m and 'ORDINARY' not in upper:
            season = 'Lent'; week = word_to_num(m.group(2)); year_cycle = 'I/II'; continue
        m = RE_ADVENT_FOOTER.search(text)
        if m and 'ORDINARY' not in upper and 'LENT' not in upper:
            season = 'Advent'; week = word_to_num(m.group(2)); year_cycle = 'I/II'; continue
        m = RE_EASTER_FOOTER.search(text)
        if m and 'ORDINARY' not in upper:
            season = 'Easter'; week = word_to_num(m.group(2)); year_cycle = 'I/II'; continue
        m = RE_WEEK_HEADER.search(text)
        if m:
            wk = word_to_num(m.group(1)); s = m.group(2).upper()
            if 'ADVENT' in s: season = 'Advent'; week = wk; year_cycle = 'I/II'
            elif 'LENT' in s: season = 'Lent'; week = wk; year_cycle = 'I/II'
            elif 'EASTER' in s: season = 'Easter'; week = wk; year_cycle = 'I/II'
            elif 'ORDINARY' in s: season = 'Ordinary Time'; week = wk
            continue

        if 'OCTAVE OF CHRISTMAS' in upper:
            season = 'Christmas'; week = 'Octave'; year_cycle = 'I/II'
        elif 'OCTAVE OF EASTER' in upper:
            season = 'Easter'; week = 'Octave'; year_cycle = 'I/II'
        elif 'ADVENT WEEKDAYS' in upper and 'DECEMBER 17' in upper:
            season = 'Advent'; week = 'Dec 17-24'; year_cycle = 'I/II'
        elif 'AFTER ASH WEDNESDAY' in upper:
            season = 'Lent'; week = 'After Ash Wed'; year_cycle = 'I/II'
        elif re.match(r'^\d+\s+ASH\s+WEDNESDAY', upper):
            season = 'Lent'; week = 'Ash Wed'; day = 'Ash Wednesday'; year_cycle = 'I/II'
        elif 'WEEKDAYS BETWEEN NEW YEAR' in upper or 'WEEKDAYS BETWEEN JANUARY' in upper:
            season = 'Christmas'; week = 'Before Epiphany'; year_cycle = 'I/II'
        elif 'WEEKDAYS BETWEEN EPIPHANY' in upper:
            season = 'Christmas'; week = 'After Epiphany'; year_cycle = 'I/II'

        dm = RE_DAY_HEADER.match(text)
        if dm:
            persist_current()
            lect_num = dm.group(1)
            day = dm.group(2).title()
            first_reading = ''
            gospel = ''
            reading_cycle = ''
            continue

        dtm = RE_DATE_HEADER.match(text)
        if dtm:
            persist_current()
            lect_num = dtm.group(1)
            day = f"{dtm.group(2).title()} {dtm.group(3)}"
            first_reading = ''
            gospel = ''
            reading_cycle = ''
            continue

        if text.upper().startswith('FIRST READING'):
            new_cycle, new_ref = parse_first_reading_line(text)
            if first_reading or gospel:
                persist_current()
                gospel = ''
            reading_cycle = new_cycle or 'ALL'
            first_reading = new_ref or ''
            continue
        m = RE_GOSPEL.match(text)
        if m and 'ACCLAMATI' not in upper:
            gospel = clean_ref(m.group(1))
            continue

    persist_current()
    for key, value in MANUAL_WEEKDAY_REFERENCES.items():
        current = refs.get(key)
        if current is None:
            refs[key] = value
            continue
        current_first, current_gospel = current
        manual_first, manual_gospel = value
        if (not current_first or not current_gospel or current_first.startswith(':') or current_gospel.startswith(':')):
            refs[key] = value
    return refs


def build_rows():
    psalm_rows = load_psalm_catalog()
    sunday_refs = load_sunday_refs()
    weekday_refs = {}
    for path in WEEKDAY_FILES:
        weekday_refs.update(extract_weekday_refs(path))
    weekday_refs.update(load_generated_weekday_backfill())

    rows = []
    for row in psalm_rows:
        out = dict(row)
        out['reading_cycle'] = ''
        out['first_reading'] = ''
        out['second_reading'] = ''
        out['gospel'] = ''
        if row['day'] == 'Sunday' and row['sunday_cycle']:
            ref = sunday_refs.get((row['season'], row['week'], row['sunday_cycle']))
            if ref:
                out['first_reading'] = ref['first_reading']
                out['second_reading'] = ref['second_reading']
                out['gospel'] = ref['gospel']
                out['reading_cycle'] = row['sunday_cycle']
        else:
            matches = []
            for (season, week, day, weekday_cycle, lect_num, reading_cycle), ref in weekday_refs.items():
                if (season, week, day, weekday_cycle, lect_num) == (
                    row['season'], row['week'], row['day'], row['weekday_cycle'], row['lectionary_number']
                ):
                    matches.append((reading_cycle, ref))
            if matches:
                for reading_cycle, ref in matches:
                    variant = dict(out)
                    variant['reading_cycle'] = reading_cycle
                    variant['first_reading'] = ref[0]
                    variant['gospel'] = ref[1]
                    rows.append(variant)
                continue
        rows.append(out)
    return rows


def write_rows(rows):
    with open(OUT_CSV, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS)
        writer.writeheader()
        for row in rows:
            writer.writerow({k: row.get(k, '') for k in FIELDS})


def audit(rows):
    sunday_total = sum(1 for r in rows if r['day'] == 'Sunday' and r['sunday_cycle'])
    sunday_with_first = sum(1 for r in rows if r['day'] == 'Sunday' and r['sunday_cycle'] and r['first_reading'])
    weekday_total = sum(1 for r in rows if r['day'] != 'Sunday')
    weekday_with_first = sum(1 for r in rows if r['day'] != 'Sunday' and r['first_reading'])
    weekday_with_gospel = sum(1 for r in rows if r['day'] != 'Sunday' and r['gospel'])
    weekday_variants = sum(1 for r in rows if r['day'] != 'Sunday' and r['reading_cycle'])
    print(f'Sunday rows: {sunday_with_first}/{sunday_total} with first reading')
    print(f'Weekday rows: {weekday_with_first}/{weekday_total} with first reading')
    print(f'Weekday rows: {weekday_with_gospel}/{weekday_total} with gospel')
    print(f'Weekday variant rows: {weekday_variants}')
    for sample in [
        ('Lent', '4', 'Sunday', '', 'A'),
        ('Ordinary Time', '17', 'Sunday', '', 'A'),
        ('Advent', '1', 'Monday', 'I/II', ''),
        ('Advent', 'Dec 17-24', 'December 24', 'I/II', ''),
    ]:
        for row in rows:
            if (row['season'], row['week'], row['day'], row['weekday_cycle'], row['sunday_cycle']) == sample:
                print(sample, '=>', row['reading_cycle'], '|', row['first_reading'], '|', row['gospel'], '|', row['psalm_reference'])
                break


if __name__ == '__main__':
    rows = build_rows()
    write_rows(rows)
    audit(rows)
    print(f'Wrote {len(rows)} rows to {OUT_CSV}')
