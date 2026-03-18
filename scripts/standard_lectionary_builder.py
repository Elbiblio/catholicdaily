import csv
import re
import sqlite3
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Tuple

from parse_weekday_lectionary import determine_cycle_from_context, extract_entries, parse_full_text

BASE_DIR = Path(__file__).resolve().parent.parent
SCRIPTS_DIR = BASE_DIR / 'scripts'
OUTPUT_CSV = BASE_DIR / 'standard_lectionary_complete.csv'
WEEKDAY_A = SCRIPTS_DIR / 'weekday_a_full.txt'
WEEKDAY_B = SCRIPTS_DIR / 'weekday_b_full.txt'
SUNDAY_TXT = SCRIPTS_DIR / 'sunday_readings_columns.txt'
RSVCE_DB = BASE_DIR / 'assets' / 'rsvce.db'

FIELDS = [
    'season', 'week', 'day', 'weekday_cycle', 'sunday_cycle', 'reading_cycle',
    'first_reading', 'second_reading', 'psalm_reference', 'psalm_response',
    'gospel', 'acclamation_ref', 'acclamation_text', 'lectionary_number',
    'first_reading_incipit', 'gospel_incipit',
    'source_file', 'source_page', 'source_title', 'reference_status', 'parser_warnings',
]

WEEK_WORDS = {
    'FIRST': '1', 'SECOND': '2', 'THIRD': '3', 'FOURTH': '4', 'FIFTH': '5', 'SIXTH': '6',
    'SEVENTH': '7', 'EIGHTH': '8', 'NINTH': '9', 'TENTH': '10', 'ELEVENTH': '11', 'TWELFTH': '12',
    'THIRTEENTH': '13', 'FOURTEENTH': '14', 'FIFTEENTH': '15', 'SIXTEENTH': '16',
    'SEVENTEENTH': '17', 'EIGHTEENTH': '18', 'NINETEENTH': '19', 'TWENTIETH': '20',
    'TWENTY-FIRST': '21', 'TWENTY-SECOND': '22', 'TWENTY-THIRD': '23', 'TWENTY-FOURTH': '24',
    'TWENTY-FIFTH': '25', 'TWENTY-SIXTH': '26', 'TWENTY-SEVENTH': '27', 'TWENTY-EIGHTH': '28',
    'TWENTY-NINTH': '29', 'THIRTIETH': '30', 'THIRTY-FIRST': '31', 'THIRTY-SECOND': '32',
    'THIRTY-THIRD': '33', 'THIRTY-FOURTH': '34',
}
WEEK_WORD_PATTERN = '|'.join(sorted(WEEK_WORDS.keys(), key=len, reverse=True))

BOOK_FIXES = {
    'Is ': 'Isa ', 'Zep ': 'Zeph ', 'Mi ': 'Mic ', 'Mt ': 'Matt ', 'Mk ': 'Mark ', 'Lk ': 'Luke ',
    'Jn ': 'John ', 'Ex ': 'Exod ', 'Gn ': 'Gen ', 'Jl ': 'Joel ', 'Dt ': 'Deut ', 'Rv ': 'Rev ',
    '1 Pt ': '1 Pet ', '2 Pt ': '2 Pet ', '1 Jn ': '1 John ', '2 Jn ': '2 John ', '3 Jn ': '3 John ',
    '1 Thes ': '1 Thess ', '2 Thes ': '2 Thess ', '1 Tm ': '1 Tim ', '2 Tm ': '2 Tim ', 'Sirach ': 'Sir ',
    'Isaiah ': 'Isa ', 'Matthew ': 'Matt ', 'Luke ': 'Luke ', 'John ': 'John ', 'Mark ': 'Mark ',
    'Genesis ': 'Gen ', 'Exodus ': 'Exod ', 'Deuteronomy ': 'Deut ', 'Baruch ': 'Bar ', 'Jeremiah ': 'Jer ',
    'Ezekiel ': 'Ezek ', 'Acts ': 'Acts ', 'Romans ': 'Rom ', 'Revelation ': 'Rev ',
}

GOSPEL_BOOKS = {'Matthew': 'Matt', 'Mark': 'Mark', 'Luke': 'Luke', 'John': 'John'}
SUNDAY_SOURCE_HEADER = 'CATHOLIC SUNDAY READINGS'
PAGE_RE = re.compile(r'^--- PAGE (\d+) (LEFT|RIGHT) ---$')
FIRST_RE = re.compile(r'^FIRST\s+READING\s*[\[(]([^\])]+)[\])]', re.IGNORECASE)
SECOND_RE = re.compile(r'^SECOND\s+READING\s*[\[(]([^\])]+)[\])]', re.IGNORECASE)
PSALM_RE = re.compile(r'^RESPONSORIAL\s+PSALM\s*[\[(]([^\])]+)[\])]', re.IGNORECASE)
ALLELUIA_RE = re.compile(r'^(?:ALLELUIA|GOSPEL\s+ACCLAMATION|VERSE\s+BEFORE\s+THE\s+GOSPEL)\s*[\[(]([^\])]+)[\])]', re.IGNORECASE)
GOSPEL_RE = re.compile(r'^GOSPEL(?:\s*[—-]\s*[ABC])?\s*[\[(]([^\])]+)[\])]', re.IGNORECASE)
GOSPEL_CYCLE_RE = re.compile(r'^GOSPEL\s*[—-]\s*([ABC])\s*[\[(]([^\])]+)[\])]', re.IGNORECASE)
OPTION_CYCLE_RE = re.compile(r'^In Year ([BC]), these readings may be used:?$', re.IGNORECASE)
ACCORDING_RE = re.compile(r'according to\s+([A-Za-z]+)', re.IGNORECASE)
WEEK_HEADER_RE = re.compile(rf'^({WEEK_WORD_PATTERN})\s+WEEK\s+(OF|IN)\s+(ADVENT|LENT|EASTER|ORDINARY\s+TIME)$', re.IGNORECASE)
REGULAR_TITLE_RE = re.compile(
    rf'^({WEEK_WORD_PATTERN}|2D)\s+SUNDAY\s+(OF|IN)\s+(ADVENT|LENT|EASTER|ORDINARY\s+TIME)\s*[—-]\s*([ABC])$',
    re.IGNORECASE,
)
PALM_TITLE_RE = re.compile(r'^PALM\s+SUNDAY\s*[—-]\s*([ABC])$', re.IGNORECASE)
CHRIST_KING_RE = re.compile(
    r'^34TH\s+\(OR\s+LAST\)\s+SUNDAY\s+IN\s+ORDINARY\s+TIME:\s+CHRIST\s+THE\s+KING\s*[—-]\s*([ABC])$',
    re.IGNORECASE,
)
SPECIAL_RE = re.compile(
    r'^(ASH\s+WEDNESDAY|PALM\s+\(PASSION\)\s+SUNDAY|HOLY\s+THURSDAY\s+\(MASS\s+OF\s+THE\s+LORD\'S\s+SUPPER\)|GOOD\s+FRIDAY\s+OF\s+THE\s+LORD\'S\s+PASSION|EASTER\s+VIGIL|CHRISTMAS\s+\(VIGIL\s+MASS\)|CHRISTMAS\s+\(MASS\s+AT\s+MIDNIGHT\)|CHRISTMAS\s+\(MASS\s+AT\s+DAWN\)|CHRISTMAS\s+\(MASS\s+DURING\s+THE\s+DAY\)|EPIPHANY\s+OF\s+THE\s+LORD|THE\s+BAPTISM\s+OF\s+THE\s+LORD|THE\s+ASCENSION\s+OF\s+THE\s+LORD|PENTECOST\s+SUNDAY\s+\(DAY\)|PENTECOST\s+SUNDAY\s+\(VIGIL\)|HOLY\s+TRINITY\s+\(1ST\s+SUNDAY\s+AFTER\s+PENTECOST\)|CORPUS\s+CHRISTI\s+\(2ND\s+SUNDAY\s+AFTER\s+PENTECOST\)|ALL\s+SAINTS\s+\(November\s+1\)|ALL\s+SOULS\s+\(November\s+2\))\s*[—-]?\s*(ABC|A|B|C)?',
    re.IGNORECASE,
)
HOLY_FAMILY_RE = re.compile(r'^HOLY\s+FAMILY.*(?:Gospel\s+([ABC])|Year\s+([BC])\s+Option)', re.IGNORECASE)

SPECIAL_CONTEXT = {
    'ASH WEDNESDAY': ('Lent', 'After Ash Wed', 'Ash Wednesday', ''),
    'PALM (PASSION) SUNDAY': ('Holy Week', '', 'Palm Sunday', ''),
    "HOLY THURSDAY (MASS OF THE LORD'S SUPPER)": ('Holy Week', '', 'Holy Thursday', ''),
    "GOOD FRIDAY OF THE LORD'S PASSION": ('Holy Week', '', 'Good Friday', ''),
    'EASTER VIGIL': ('Easter', 'Vigil', 'Easter Vigil', ''),
    'CHRISTMAS (VIGIL MASS)': ('Christmas', 'Christmas', 'Christmas Vigil', ''),
    'CHRISTMAS (MASS AT MIDNIGHT)': ('Christmas', 'Christmas', 'Christmas Midnight', ''),
    'CHRISTMAS (MASS AT DAWN)': ('Christmas', 'Christmas', 'Christmas Dawn', ''),
    'CHRISTMAS (MASS DURING THE DAY)': ('Christmas', 'Christmas', 'Christmas Day', ''),
    'EPIPHANY OF THE LORD': ('Christmas', 'Epiphany', 'Sunday', ''),
    'THE BAPTISM OF THE LORD': ('Christmas', 'Baptism of the Lord', 'Sunday', ''),
    'THE ASCENSION OF THE LORD': ('Easter', 'Ascension', 'Sunday', ''),
    'PENTECOST SUNDAY (DAY)': ('Easter', 'Pentecost', 'Sunday', ''),
    'PENTECOST SUNDAY (VIGIL)': ('Easter', 'Pentecost Vigil', 'Pentecost Vigil', ''),
    'HOLY TRINITY (1ST SUNDAY AFTER PENTECOST)': ('Ordinary Time', 'Holy Trinity', 'Sunday', ''),
    'CORPUS CHRISTI (2ND SUNDAY AFTER PENTECOST)': ('Ordinary Time', 'Corpus Christi', 'Sunday', ''),
    'ALL SAINTS (November 1)': ('Solemnities', 'All Saints', 'All Saints', ''),
    'ALL SOULS (November 2)': ('Solemnities', 'All Souls', 'All Souls', ''),
}


def normalize_source_text(value: str) -> str:
    text = (value or '').replace('—', '-').replace('–', '-').replace('“', '"').replace('”', '"').replace('’', "'")
    text = re.sub(r'\bGO\s+S\s+P\s+E\s+L\b', 'GOSPEL', text, flags=re.IGNORECASE)
    text = re.sub(r'\bGOSPEL\s+ACCLAMATI\s+O\s+N\b', 'GOSPEL ACCLAMATION', text, flags=re.IGNORECASE)
    text = re.sub(r'\(\s*s\s*h\s*o\s*r\s*t?\s*e\s*r\s*\)', '(shorter)', text, flags=re.IGNORECASE)
    text = text.replace('SARURDAY', 'SATURDAY')
    text = text.replace('Chirst', 'Christ')
    return text


def clean_reference(value: str) -> str:
    text = ' '.join(normalize_source_text(value).split())
    text = text.replace('Psalm ', 'Ps ')
    text = text.replace('cf. Psalm ', 'cf. Ps ')
    text = re.sub(r'\bcf\.\s+Mt\b', 'cf. Matt', text)
    text = re.sub(r'\bcf\.\s+Mk\b', 'cf. Mark', text)
    text = re.sub(r'\bcf\.\s+Lk\b', 'cf. Luke', text)
    text = re.sub(r'\bcf\.\s+Jn\b', 'cf. John', text)
    text = text.replace('++', '')
    text = text.replace('@', '')
    text = re.sub(r'\b(?:Shorter\s+form|Longer\s+form)\s*:\s*', '', text, flags=re.IGNORECASE)
    for old, new in BOOK_FIXES.items():
        if text.startswith(old):
            text = new + text[len(old):]
    text = re.sub(r'\bMt\s+', 'Matt ', text)
    text = re.sub(r'\bMk\s+', 'Mark ', text)
    text = re.sub(r'\bLk\s+', 'Luke ', text)
    text = re.sub(r'\bJn\s+', 'John ', text)
    text = re.sub(r'^(Matt|Mark|Luke|John)\s+(Matthew|Mark|Luke|John)\s+', r'\1 ', text)
    text = text.replace('Matt Matt ', 'Matt ')
    text = text.replace('Matt Matthew ', 'Matt ')
    text = text.replace('Mark Mark ', 'Mark ')
    text = text.replace('Luke Luke ', 'Luke ')
    text = text.replace('John John ', 'John ')
    text = text.replace('Matt Matt ', 'Matt ')
    text = text.replace('Matt Mt ', 'Matt ')
    text = text.replace('Mark Mk ', 'Mark ')
    text = text.replace('Luke Lk ', 'Luke ')
    text = text.replace('John Jn ', 'John ')
    text = re.sub(r'\b2\s+Corinthians\s+8\.93\b', '2 Corinthians 8:9', text)
    text = re.sub(r'\bJohn\s+21\.173\b', 'John 21:17-18', text)
    return text.strip(' ,;')


def clean_line(value: str) -> str:
    text = ' '.join(normalize_source_text(value).split())
    if not text:
        return ''
    if text.startswith('Text copyright') or 'Catholic Religious Support Handbo' in text:
        return ''
    if text in {'(cid:1)', '-'}:
        return ''
    if re.match(r'^=+$', text):
        return ''
    if re.match(r'^PAGE\s+\d+$', text, re.IGNORECASE):
        return ''
    if re.match(r'^---\s*PAGE\s+\d+\s+(LEFT|RIGHT)\s*---$', text, re.IGNORECASE):
        return ''
    if re.match(r'^\[\s*Short(?:er)? form in brackets\.?\s*\]$', text, re.IGNORECASE):
        return ''
    if re.match(r'^Only shorter form(?: of Gospel)?(?: is)? given below\.?$', text, re.IGNORECASE):
        return ''
    return text


def sanitize_incipit(text: str) -> str:
    text = ' '.join(text.split())
    text = text.strip('[] ')
    text = re.sub(r'^\d+[a-z]?\.\s*', '', text, flags=re.IGNORECASE)
    text = re.sub(r'^\d+[a-z]?\s+', '', text, flags=re.IGNORECASE)
    text = re.sub(rf'\b\d+\s+({WEEK_WORD_PATTERN})\s+WEEK\b.*$', '', text, flags=re.IGNORECASE)
    text = re.sub(r'\b\d+\s+[A-Z][A-Z\s–-]+$', '', text)
    return text.strip(' ,;:-')


def clean_response_text(text: str) -> str:
    value = clean_line(text)
    value = re.sub(r'^R\.\s*', '', value)
    value = re.sub(r'^\((?:cf\.[^)]+|[^)]+)\)\s*', '', value, flags=re.IGNORECASE)
    value = re.sub(r'^(?:This verse may accompany the singing of the Alleluia\.?\s*)+', '', value, flags=re.IGNORECASE)
    value = re.sub(r'^(?:If the Alleluia is not sung, the acclamation is omitted\.?\s*|If the acclamation is not sung, it is omitted\.?\s*|If the acclamation is omitted\.?\s*|acclamation is omitted\.?\s*|mation is omitted\.?\s*)+', '', value, flags=re.IGNORECASE)
    value = re.sub(r'[—-]\s*R\.\s*$', '', value)
    value = re.sub(r'\b(?:JANUARY|FEBRUARY|MARCH|APRIL|MAY|JUNE|JULY|AUGUST|SEPTEMBER|OCTOBER|NOVEMBER|DECEMBER|MONDAY|TUESDAY|WEDNESDAY|THURSDAY|FRIDAY|SATURDAY)\s+\d+$', '', value, flags=re.IGNORECASE)
    value = value.replace('++', '')
    value = value.replace('@', '')
    return value.strip(' :-')


def is_section_break(line: str) -> bool:
    upper = line.upper()
    if not line:
        return True
    if line == '@':
        return True
    if upper.startswith(('FIRST READING', 'SECOND READING', 'RESPONSORIAL PSALM', 'ALLELUIA', 'GOSPEL ACCLAMATION', 'VERSE BEFORE THE GOSPEL', 'GOSPEL (', 'GOSPEL-[', 'GOSPEL—', 'GO S P E L')):
        return True
    if line.startswith(('A reading from', '+ A reading from', 'The word of the Lord', 'The Gospel of the Lord')):
        return True
    if re.match(r'^(\d+)\s+(MONDAY|TUESDAY|WEDNESDAY|THURSDAY|FRIDAY|SATURDAY)$', line):
        return True
    if re.match(rf'^(?:\d+\s+)?({WEEK_WORD_PATTERN})\s+WEEK\s+(?:OF|IN)\s+', upper):
        return True
    if re.match(r'^(JANUARY|FEBRUARY|MARCH|APRIL|MAY|JUNE|JULY|AUGUST|SEPTEMBER|OCTOBER|NOVEMBER|DECEMBER|MONDAY|TUESDAY|WEDNESDAY|THURSDAY|FRIDAY|SATURDAY)\s+\d+$', upper):
        return True
    return False


def is_response_continuation(previous: str, current: str) -> bool:
    if not previous or not current:
        return False
    prev = previous.strip()
    curr = current.strip()
    if not prev.endswith((';', ',', ':')):
        return False
    if curr[:1].islower():
        return True
    return bool(re.match(r'^(and|or|let|that|for|to|all|with|in|of|the)\b', curr, re.IGNORECASE))


def should_join_incipit(candidate: str) -> bool:
    if not candidate:
        return False
    if len(candidate) > 40:
        return False
    if candidate.endswith(('.', '?', '!')):
        return False
    return bool(
        candidate.endswith(':') or
        re.match(
            r'^(?:Beloved|My child|My son|My daughter|Children|Brothers and sisters|The Holy Spirit says|Thus says the Lord|Thus says the LORD|Jesus said|Moses said|Paul said|The Lord God says this|Job spoke, saying|My friends|From James|In the beginning|The Lord saw|The angel brought me|As I watched)\b',
            candidate,
            re.IGNORECASE,
        )
    )


def incipit_join_separator(candidate: str) -> str:
    lower = candidate.lower().strip()
    if candidate.endswith(':'):
        return ' '
    if re.search(r'(?:says this|spoke, saying|says|said)$', lower):
        return ': '
    if re.match(r'^(?:my friends|from james|as i watched)\b', lower):
        return ', '
    return ' '


def join_incipit_lines(candidate: str, next_candidate: str) -> str:
    separator = incipit_join_separator(candidate)
    candidate_clean = candidate.strip().rstrip('.')
    next_clean = next_candidate.strip().rstrip('.')
    candidate_lower = candidate_clean.lower().rstrip(',:;')
    next_lower = next_clean.lower()

    overlap_phrases = [
        'the gate',
        'the temple',
        'the city',
        'the lord',
        'the people',
    ]
    for phrase in overlap_phrases:
        if candidate_lower.endswith(phrase) and next_lower.startswith(f'{phrase} '):
            next_clean = next_clean[len(phrase):].strip()
            break

    if separator == ' ' and candidate_clean.endswith(',') and next_clean[:1].islower():
        return f"{candidate_clean} {next_clean}"
    return f"{candidate_clean}{separator}{next_clean}"


def extract_incipit(lines: Iterable[str], gospel: bool = False) -> str:
    cleaned = [clean_line(raw) for raw in lines]
    anchor_present = any(line == '@' or line.startswith(('A reading from', '+ A reading from')) for line in cleaned if line)
    start_collecting = not anchor_present
    for index, line in enumerate(cleaned):
        if not line:
            continue
        if line == '@' or line.startswith(('A reading from', '+ A reading from')):
            start_collecting = True
            continue
        if is_section_break(line):
            if start_collecting:
                break
            continue
        if not start_collecting:
            continue
        candidate = sanitize_incipit(line)
        if not candidate:
            continue
        if gospel and re.match(r'^The Passion of our Lord Jesus Christ according to\s+', candidate, re.IGNORECASE):
            continue
        if re.match(r'^\[?\s*Short(?:er)? form in brackets\.?\s*\]?$', candidate, re.IGNORECASE):
            continue
        if re.match(r'^Only shorter form(?: of Gospel)?(?: is)? given below\.?$', candidate, re.IGNORECASE):
            continue
        if should_join_incipit(candidate):
            for next_line in cleaned[index + 1:]:
                if not next_line:
                    continue
                if is_section_break(next_line):
                    break
                next_candidate = sanitize_incipit(next_line)
                if not next_candidate:
                    continue
                return join_incipit_lines(candidate, next_candidate)
        return candidate
    return ''


def reference_options(reference: str) -> List[str]:
    return [clean_reference(part.strip()) for part in re.split(r'\s+or\s+', reference or '', flags=re.IGNORECASE) if part.strip()]


def extract_multiline_response(lines: Iterable[str]) -> str:
    parts: List[str] = []
    previous_part = ''
    for raw in lines:
        line = clean_line(raw)
        if not line:
            continue
        if line.lower() == 'or:':
            if parts:
                break
            continue
        if line.startswith('R. '):
            if parts:
                break
            previous_part = clean_response_text(line)
            parts.append(previous_part)
            continue
        if parts:
            if re.match(r'^\d+\s', line) or is_section_break(line):
                break
            current_part = clean_response_text(line)
            if is_response_continuation(previous_part, current_part):
                parts.append(current_part)
                previous_part = current_part
                continue
            break
    return ' '.join(part for part in parts if part).strip()


def extract_acclamation_text(lines: Iterable[str]) -> str:
    parts: List[str] = []
    for raw in lines:
        line = clean_line(raw)
        if not line:
            continue
        if line.lower() == 'or:' and parts:
            break
        if is_section_break(line):
            break
        cleaned = clean_response_text(line)
        if not cleaned:
            continue
        if line.startswith('R. '):
            parts.append(cleaned)
            continue
        parts.append(cleaned)
    return sanitize_incipit(' '.join(part for part in parts if part))


def week_num(label: str) -> str:
    return WEEK_WORDS.get(label.upper().replace('2D', 'SECOND'), label)


def parse_weekday_first_line(line: str) -> Tuple[str, str]:
    text = clean_line(line)
    remainder = re.sub(r'^FIRST\s+READING', '', text, flags=re.IGNORECASE).strip()
    if remainder.startswith(('–', '-')):
        remainder = remainder[1:].strip()
    cycle_remainder = re.match(r'^YEAR[S]?\s+(.+)$', remainder, re.IGNORECASE)
    if cycle_remainder:
        tokens = cycle_remainder.group(1).split()
        cycle_tokens: List[str] = []
        idx = 0
        while idx < len(tokens):
            token = tokens[idx].rstrip(',').upper()
            if token in {'A', 'B', 'C', 'I', 'II'}:
                cycle_tokens.append(token)
                idx += 1
                continue
            break
        if cycle_tokens and idx < len(tokens):
            return ','.join(cycle_tokens), clean_reference(' '.join(tokens[idx:]))
    return 'ALL', clean_reference(remainder)


def validator_status(*refs: str) -> str:
    if not RSVCE_DB.exists():
        return 'unverified'
    try:
        conn = sqlite3.connect(str(RSVCE_DB))
        cursor = conn.cursor()
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
        tables = {row[0] for row in cursor.fetchall()}
        if 'verses' not in tables:
            conn.close()
            return 'unverified'
        cursor.execute('PRAGMA table_info(verses)')
        columns = [row[1] for row in cursor.fetchall()]
        book_col = next((col for col in columns if col.lower() in {'book', 'book_name'}), None)
        if not book_col:
            conn.close()
            return 'unverified'
        cursor.execute(f'SELECT DISTINCT {book_col} FROM verses')
        books = {str(row[0]).strip() for row in cursor.fetchall() if row and row[0]}
        conn.close()
    except Exception:
        return 'unverified'
    used = []
    for ref in refs:
        match = re.match(r'^(\d\s+)?([A-Za-z]+)', ref or '')
        if match:
            used.append(match.group(0).strip())
    if not used:
        return 'missing'
    return 'grounded' if all(book in books for book in used) else 'partial'


def extract_weekday_refs(path: Path) -> Dict[Tuple[str, str, str, str, str, str], Tuple[str, str, str, str]]:
    lines = path.read_text(encoding='utf-8').splitlines()
    footer_ot = re.compile(rf'(\d+)\s+({WEEK_WORD_PATTERN})\s+WEEK\s+IN\s+ORDINARY\s+TIME\s*[–-]\s*YEAR\s+(I{{1,2}})', re.IGNORECASE)
    footer_lent = re.compile(rf'(\d+)\s+({WEEK_WORD_PATTERN})\s+WEEK\s+OF\s+LENT', re.IGNORECASE)
    footer_advent = re.compile(rf'(\d+)\s+({WEEK_WORD_PATTERN})\s+WEEK\s+OF\s+ADVENT', re.IGNORECASE)
    footer_easter = re.compile(rf'(\d+)\s+({WEEK_WORD_PATTERN})\s+WEEK\s+OF\s+EASTER', re.IGNORECASE)
    day_header = re.compile(r'^(\d{1,4})\s+(MONDAY|TUESDAY|WEDNESDAY|THURSDAY|FRIDAY|SATURDAY)$')
    date_header = re.compile(r'^(\d{1,4})\s+(DECEMBER|JANUARY|FEBRUARY|MARCH|APRIL|MAY|JUNE)\s+(\d{1,2})$')
    first_re = re.compile(r'^FIRST\s+READING', re.IGNORECASE)
    gospel_re = re.compile(r'^GO\s*S\s*P\s*E\s*L\s+(.+)$', re.IGNORECASE)
    season = week = day = lect = cycle = reading_cycle = ''
    first_ref = gospel_ref = first_incipit = gospel_incipit = ''
    current_lines: List[str] = []
    current_kind = ''
    pending_firsts: List[Tuple[str, str, str]] = []
    refs: Dict[Tuple[str, str, str, str, str, str], Tuple[str, str, str, str]] = {}

    def reset_day_state() -> None:
        nonlocal reading_cycle, first_ref, gospel_ref, first_incipit, gospel_incipit, current_lines, current_kind, pending_firsts
        reading_cycle = ''
        first_ref = ''
        gospel_ref = ''
        first_incipit = ''
        gospel_incipit = ''
        current_lines = []
        current_kind = ''
        pending_firsts = []

    def finalize_active_first() -> None:
        nonlocal first_ref, first_incipit, current_lines, current_kind, reading_cycle, pending_firsts
        if current_kind == 'first' and first_ref:
            first_incipit = extract_incipit(current_lines)
            pending_firsts.append((reading_cycle, first_ref, first_incipit))
            first_ref = ''
            first_incipit = ''
            current_lines = []
            current_kind = ''

    def finalize_active_gospel() -> None:
        nonlocal gospel_incipit, current_lines, current_kind
        if current_kind == 'gospel' and gospel_ref:
            gospel_incipit = extract_incipit(current_lines, gospel=True)
            current_lines = []
            current_kind = ''

    def persist() -> None:
        finalize_active_first()
        finalize_active_gospel()
        if not (season and week and day):
            return
        if pending_firsts:
            for variant_cycle, variant_first_ref, variant_first_incipit in pending_firsts:
                refs[(season, week, day, cycle, lect, variant_cycle)] = (variant_first_ref, gospel_ref, variant_first_incipit, gospel_incipit)
        elif gospel_ref:
            refs[(season, week, day, cycle, lect, reading_cycle)] = ('', gospel_ref, '', gospel_incipit)

    for raw in lines:
        line = clean_line(raw)
        upper = line.upper()
        if not line:
            continue
        week_header_match = WEEK_HEADER_RE.match(upper)
        if week_header_match:
            season_name = week_header_match.group(3).upper()
            week = week_num(week_header_match.group(1))
            if 'ADVENT' in season_name:
                season = 'Advent'
                cycle = 'I/II'
            elif 'LENT' in season_name:
                season = 'Lent'
                cycle = 'I/II'
            elif 'EASTER' in season_name:
                season = 'Easter'
                cycle = 'I/II'
            elif 'ORDINARY' in season_name:
                season = 'Ordinary Time'
            continue
        for regex, season_name, seasonal_cycle in [
            (footer_ot, 'Ordinary Time', None),
            (footer_lent, 'Lent', 'I/II'),
            (footer_advent, 'Advent', 'I/II'),
            (footer_easter, 'Easter', 'I/II'),
        ]:
            match = regex.search(line)
            if match:
                season = season_name
                week = week_num(match.group(2))
                cycle = match.group(3).upper() if season_name == 'Ordinary Time' else seasonal_cycle or cycle
        if 'OCTAVE OF CHRISTMAS' in upper:
            season, week, cycle = 'Christmas', 'Octave', 'I/II'
        elif 'OCTAVE OF EASTER' in upper:
            season, week, cycle = 'Easter', 'Octave', 'I/II'
        elif 'ADVENT WEEKDAYS' in upper and 'DECEMBER 17' in upper:
            season, week, cycle = 'Advent', 'Dec 17-24', 'I/II'
        elif 'AFTER ASH WEDNESDAY' in upper:
            season, week, cycle = 'Lent', 'After Ash Wed', 'I/II'
        elif 'WEEKDAYS BETWEEN EPIPHANY' in upper:
            season, week, cycle = 'Christmas', 'After Epiphany', 'I/II'
        day_match = day_header.match(line)
        if day_match:
            persist()
            lect, day = day_match.group(1), day_match.group(2).title()
            reset_day_state()
            if season == 'Ordinary Time' and not cycle:
                cycle = 'I' if path.stem.endswith('a_full') else 'II'
            continue
        date_match = date_header.match(line)
        if date_match:
            persist()
            lect = date_match.group(1)
            day = f'{date_match.group(2).title()} {date_match.group(3)}'
            cycle = 'I/II'
            reset_day_state()
            reading_cycle = 'ALL'
            continue
        first_match = first_re.match(line)
        if first_match:
            if current_kind == 'gospel' and current_lines:
                finalize_active_gospel()
            elif current_kind == 'first' and first_ref:
                finalize_active_first()
            current_kind = 'first'
            current_lines = []
            reading_cycle, first_ref = parse_weekday_first_line(line)
            continue
        gospel_match = gospel_re.match(line)
        if gospel_match and 'ACCLAMATI' not in upper:
            if current_kind == 'first' and first_ref:
                finalize_active_first()
            current_kind = 'gospel'
            current_lines = []
            gospel_ref = clean_reference(gospel_match.group(1))
            continue
        if current_kind in {'first', 'gospel'}:
            current_lines.append(line)
    persist()
    return refs


def load_weekday_rows() -> List[Dict[str, str]]:
    rows_a = determine_cycle_from_context(extract_entries(parse_full_text(str(WEEKDAY_A)), pdf_label='A'), 'A')
    rows_b = determine_cycle_from_context(extract_entries(parse_full_text(str(WEEKDAY_B)), pdf_label='B'), 'B')
    combined: List[Dict[str, str]] = []
    seen = set()
    for item in rows_a + rows_b:
        key = (
            item['season'], item['week'], item['day'], item['weekday_cycle'],
            item['psalm_reference'], item['acclamation_ref'], item['acclamation_text'], item['lectionary_number'],
        )
        if key not in seen:
            seen.add(key)
            combined.append(item)
    refs: Dict[Tuple[str, str, str, str, str, str], Tuple[str, str, str, str]] = {}
    refs.update(extract_weekday_refs(WEEKDAY_A))
    refs.update(extract_weekday_refs(WEEKDAY_B))
    result: List[Dict[str, str]] = []
    for item in combined:
        row_matches = [
            (key, value)
            for key, value in refs.items()
            if key[:5] == (item['season'], item['week'], item['day'], item['weekday_cycle'], item['lectionary_number'])
        ]
        if not row_matches:
            row_matches = [((item['season'], item['week'], item['day'], item['weekday_cycle'], item['lectionary_number'], ''), ('', '', '', ''))]
        for key, value in row_matches:
            first_ref, gospel_ref, first_incipit, gospel_incipit = value
            warnings = []
            if 'WEEK OF' in first_incipit.upper() or 'WEEK OF' in gospel_incipit.upper():
                warnings.append('sanitized_incipit')
            result.append({
                'season': item['season'],
                'week': item['week'],
                'day': item['day'],
                'weekday_cycle': item['weekday_cycle'],
                'sunday_cycle': '',
                'reading_cycle': key[5],
                'first_reading': first_ref,
                'second_reading': '',
                'psalm_reference': clean_reference(item['psalm_reference']),
                'psalm_response': clean_response_text(item['response_text']),
                'gospel': gospel_ref,
                'acclamation_ref': clean_reference(item['acclamation_ref']),
                'acclamation_text': extract_acclamation_text(item['acclamation_text'].splitlines() if isinstance(item['acclamation_text'], str) else item['acclamation_text']),
                'lectionary_number': item['lectionary_number'],
                'first_reading_incipit': sanitize_incipit(first_incipit),
                'gospel_incipit': sanitize_incipit(gospel_incipit),
                'source_file': path_label_for_cycle(item['weekday_cycle']),
                'source_page': '',
                'source_title': f"{item['season']} {item['week']} {item['day']}".strip(),
                'reference_status': validator_status(first_ref, '', gospel_ref),
                'parser_warnings': '|'.join(warnings),
            })
    return result


def path_label_for_cycle(weekday_cycle: str) -> str:
    if weekday_cycle == 'I':
        return 'weekday_a_full.txt'
    if weekday_cycle == 'II':
        return 'weekday_b_full.txt'
    return 'weekday_a_full.txt|weekday_b_full.txt'


def parse_sunday_context(title: str) -> Optional[Tuple[str, str, str, str]]:
    title = title.strip()
    match = REGULAR_TITLE_RE.match(title)
    if match:
        return match.group(3).title(), week_num(match.group(1)), 'Sunday', match.group(4).upper()
    match = PALM_TITLE_RE.match(title)
    if match:
        return 'Holy Week', '', 'Palm Sunday', match.group(1).upper()
    match = CHRIST_KING_RE.match(title)
    if match:
        return 'Ordinary Time', '34', 'Sunday', match.group(1).upper()
    match = HOLY_FAMILY_RE.match(title)
    if match:
        cycle = (match.group(1) or match.group(2) or '').upper()
        return 'Christmas', 'Holy Family', 'Sunday', cycle
    match = SPECIAL_RE.match(title)
    if match:
        label = match.group(1).upper()
        context = SPECIAL_CONTEXT.get(label)
        if context:
            cycle = (match.group(2) or 'ABC').upper()
            return context[0], context[1], context[2], cycle
    upper = title.upper()
    if upper.startswith('IMMACULATE CONCEPTION'):
        return 'Solemnities', 'Immaculate Conception', 'Immaculate Conception', 'ABC'
    if upper.startswith('SACRED HEART OF JESUS'):
        return 'Solemnities', 'Sacred Heart', 'Sacred Heart', upper.rsplit('—', 1)[-1].split()[0] if '—' in upper else 'ABC'
    if upper.startswith('NATIVITY OF JOHN THE BAPTIST (VIGIL)'):
        return 'Solemnities', 'Nativity of John the Baptist', 'Nativity of John the Baptist Vigil', 'ABC'
    if upper.startswith('NATIVITY OF JOHN THE BAPTIST (DAY)'):
        return 'Solemnities', 'Nativity of John the Baptist', 'Nativity of John the Baptist', 'ABC'
    if upper.startswith('SS. PETER AND PAUL, APOSTLES (VIGIL)'):
        return 'Solemnities', 'SS. Peter and Paul, Apostles', 'SS. Peter and Paul, Apostles Vigil', 'ABC'
    if upper.startswith('SS. PETER AND PAUL, APOSTLES (DAY)'):
        return 'Solemnities', 'SS. Peter and Paul, Apostles', 'SS. Peter and Paul, Apostles', 'ABC'
    if upper.startswith('TRANSFIGURATION OF THE LORD'):
        cycle_match = re.search(r'[—-]\s*([ABC])\b', upper)
        return 'Solemnities', 'Transfiguration of the Lord', 'Transfiguration of the Lord', cycle_match.group(1) if cycle_match else 'ABC'
    if upper.startswith('BODY AND BLOOD OF CHRIST'):
        cycle_match = re.search(r'[—-]\s*([ABC])\b', upper)
        return 'Solemnities', 'Body and Blood of Christ', 'Body and Blood of Christ', cycle_match.group(1) if cycle_match else 'ABC'
    if upper.startswith('ASSUMPTION OF THE BLESSED VIRGIN MARY (VIGIL)'):
        return 'Solemnities', 'Assumption', 'Assumption Vigil', 'ABC'
    if upper.startswith('ASSUMPTION OF THE BLESSED VIRGIN MARY (DAY)'):
        return 'Solemnities', 'Assumption', 'Assumption', 'ABC'
    if upper.startswith('EXALTATION OF THE HOLY CROSS'):
        return 'Solemnities', 'Exaltation of the Holy Cross', 'Exaltation of the Holy Cross', 'ABC'
    if upper.startswith('DEDICATION OF ST. JOHN LATERAN BASILICA'):
        return 'Solemnities', 'Dedication of St. John Lateran Basilica', 'Dedication of St. John Lateran Basilica', 'ABC'
    if upper.startswith('THE BAPTISM OF THE LORD'):
        return 'Christmas', 'Baptism of the Lord', 'Sunday', ''
    if upper.startswith('HOLY SATURDAY (EASTER VIGIL)'):
        return 'Easter', 'Vigil', 'Easter Vigil', 'ABC'
    if upper.startswith('EASTER VIGIL'):
        return 'Easter', 'Vigil', 'Easter Vigil', 'ABC'
    return None


def load_sunday_rows() -> List[Dict[str, str]]:
    lines = SUNDAY_TXT.read_text(encoding='utf-8').splitlines()
    rows: List[Dict[str, str]] = []
    current: Optional[Tuple[str, str, str, str]] = None
    current_page = ''
    active_cycle = ''
    awaiting_title = False
    refs = {'first': '', 'second': '', 'psalm': '', 'acclamation': '', 'gospel': ''}
    sections: Dict[str, List[str]] = {'first': [], 'second': [], 'psalm': [], 'acclamation': [], 'gospel': []}
    active = ''

    def flush(*, preserve_common: bool = False) -> None:
        nonlocal refs, sections, active, active_cycle
        if current is None or not refs['first']:
            if not preserve_common:
                refs = {'first': '', 'second': '', 'psalm': '', 'acclamation': '', 'gospel': ''}
                sections = {'first': [], 'second': [], 'psalm': [], 'acclamation': [], 'gospel': []}
                active = ''
                active_cycle = current[3] if current else ''
            return
        warnings = []
        gospel_incipit = sanitize_incipit(extract_incipit(sections['gospel'], gospel=True))
        if 'WEEK OF' in gospel_incipit.upper():
            warnings.append('sanitized_incipit')
        row_cycle = (active_cycle or current[3]).upper()
        rows.append({
            'season': current[0],
            'week': current[1],
            'day': current[2],
            'weekday_cycle': '',
            'sunday_cycle': row_cycle,
            'reading_cycle': row_cycle,
            'first_reading': clean_reference(refs['first']),
            'second_reading': clean_reference(refs['second']),
            'psalm_reference': clean_reference(refs['psalm']),
            'psalm_response': extract_multiline_response(sections['psalm']),
            'gospel': clean_reference(refs['gospel']),
            'acclamation_ref': clean_reference(refs['acclamation']),
            'acclamation_text': extract_acclamation_text(sections['acclamation']),
            'lectionary_number': '',
            'first_reading_incipit': sanitize_incipit(extract_incipit(sections['first'])),
            'gospel_incipit': gospel_incipit,
            'source_file': 'sunday_readings_columns.txt',
            'source_page': current_page,
            'source_title': f"{current[0]} {current[1]} {current[2]} {current[3]}".strip(),
            'reference_status': validator_status(refs['first'], refs['second'], refs['gospel']),
            'parser_warnings': '|'.join(warnings),
        })
        if preserve_common:
            refs['gospel'] = ''
            sections['gospel'] = []
            active = ''
            return
        refs = {'first': '', 'second': '', 'psalm': '', 'acclamation': '', 'gospel': ''}
        sections = {'first': [], 'second': [], 'psalm': [], 'acclamation': [], 'gospel': []}
        active = ''
        active_cycle = current[3] if current else ''

    for raw in lines:
        page_match = PAGE_RE.match(raw.strip())
        if page_match:
            current_page = page_match.group(1)
            continue
        line = clean_line(raw)
        if not line:
            continue
        if line == SUNDAY_SOURCE_HEADER:
            awaiting_title = True
            continue
        if awaiting_title:
            context = parse_sunday_context(line)
            if context:
                flush()
                current = context
                active_cycle = current[3]
                awaiting_title = False
                continue
            if re.match(r'^(SEASON OF|THE SEASON OF)\b', line, re.IGNORECASE):
                continue
            awaiting_title = False
        if current is None:
            continue
        option_cycle_match = OPTION_CYCLE_RE.match(line)
        if option_cycle_match:
            active_cycle = option_cycle_match.group(1).upper()
            continue
        first_match = FIRST_RE.match(line)
        second_match = SECOND_RE.match(line)
        psalm_match = PSALM_RE.match(line)
        acclamation_match = ALLELUIA_RE.match(line)
        gospel_cycle_match = GOSPEL_CYCLE_RE.match(line)
        gospel_match = GOSPEL_RE.match(line)
        if first_match:
            refs['first'] = first_match.group(1)
            active = 'first'
            continue
        if second_match:
            refs['second'] = second_match.group(1)
            active = 'second'
            continue
        if psalm_match:
            refs['psalm'] = psalm_match.group(1)
            active = 'psalm'
            continue
        if acclamation_match:
            refs['acclamation'] = acclamation_match.group(1)
            active = 'acclamation'
            continue
        if gospel_cycle_match:
            if refs['gospel']:
                flush(preserve_common=True)
            active_cycle = gospel_cycle_match.group(1).upper()
            refs['gospel'] = gospel_cycle_match.group(2)
            active = 'gospel'
            continue
        if gospel_match:
            refs['gospel'] = gospel_match.group(1)
            active = 'gospel'
            continue
        if active == 'gospel' and refs['gospel'] and not re.match(r'^(Matt|Matthew|Mark|Mk|Luke|Lk|John|Jn)\b', refs['gospel']):
            book_match = ACCORDING_RE.search(line)
            if book_match:
                bare_gospel_ref = re.sub(r'^cf\.\s*', '', refs['gospel'], flags=re.IGNORECASE)
                bare_gospel_ref = re.sub(r'^(?:Matt(?:hew)?|Mark|Luke|John)\s+', '', bare_gospel_ref, flags=re.IGNORECASE)
                refs['gospel'] = f"{GOSPEL_BOOKS.get(book_match.group(1).title(), book_match.group(1).title())} {bare_gospel_ref}"
                continue
        if active:
            sections[active].append(line)
    flush()
    filtered_rows: List[Dict[str, str]] = []
    for row in rows:
        source_page_num = int(row['source_page']) if row['source_page'].isdigit() else 0
        if source_page_num >= 236 and row['season'] != 'Solemnities':
            continue
        row_options = reference_options(row['gospel'])
        base_exists = any(
            existing is not row and
            existing['season'] == row['season'] and
            existing['week'] == row['week'] and
            existing['day'] == row['day'] and
            existing['sunday_cycle'] == row['sunday_cycle'] and
            existing['first_reading'] == row['first_reading'] and
            existing['second_reading'] == row['second_reading'] and
            existing['psalm_reference'] == row['psalm_reference'] and
            len(reference_options(existing['gospel'])) > 1 and
            all(option in reference_options(existing['gospel']) for option in row_options)
            for existing in rows
        )
        if base_exists and len(row_options) == 1:
            continue
        filtered_rows.append(row)
    deduped: List[Dict[str, str]] = []
    seen = set()
    for row in filtered_rows:
        if row['season'] == 'Easter' and row['week'] == 'Vigil':
            continue
        key = (row['season'], row['week'], row['day'], row['sunday_cycle'], row['first_reading'], row['second_reading'], row['psalm_reference'], row['gospel'])
        if key not in seen:
            seen.add(key)
            deduped.append(row)
    return deduped


def load_easter_vigil_rows() -> List[Dict[str, str]]:
    lines = [clean_line(line) for line in SUNDAY_TXT.read_text(encoding='utf-8').splitlines()]
    try:
        start = lines.index('EASTER VIGIL—ABC')
        end = lines.index('EASTER DAY—ABC')
    except ValueError:
        return []
    section = lines[start:end]

    def line_after(prefix: str) -> str:
        for idx, line in enumerate(section):
            if line.startswith(prefix):
                for candidate in section[idx + 1:]:
                    if candidate:
                        return candidate
        return ''

    def match_group(pattern: str) -> str:
        regex = re.compile(pattern, re.IGNORECASE)
        for line in section:
            match = regex.match(line)
            if match:
                return clean_reference(match.group(1))
        return ''

    def response_after(prefix: str) -> str:
        for idx, line in enumerate(section):
            if line.startswith(prefix):
                return extract_multiline_response(section[idx + 1:idx + 10])
        return ''

    gospel_a = match_group(r'^GOSPEL[—-]A\s*\(([^)]+)\)')
    gospel_b = match_group(r'^GOSPEL[—-]B\s*\(([^)]+)\)')
    gospel_c = match_group(r'^GOSPEL[—-]C\s*\(([^)]+)\)')
    gospel = ' or '.join(part for part in [gospel_a, gospel_b, gospel_c] if part)
    acclamation_ref = match_group(r'^ALLELUIA\s*\(([^)]+)\)')
    acclamation_idx = next((idx for idx, line in enumerate(section) if re.match(r'^ALLELUIA\s*\(', line, re.IGNORECASE)), -1)
    acclamation_text = extract_acclamation_text(section[acclamation_idx + 1:] if acclamation_idx >= 0 else [])

    page_map = {
        'Easter Vigil - Psalm 1': '83',
        'Easter Vigil - Psalm 1 (Alt)': '84',
        'Easter Vigil - Psalm 2': '85',
        'Easter Vigil - Psalm 3': '86',
        'Easter Vigil - Psalm 4': '87',
        'Easter Vigil - Psalm 5': '87',
        'Easter Vigil - Psalm 5 (Alt)': '88',
        'Easter Vigil - Psalm 6': '88',
        'Easter Vigil - Psalm 7': '89',
        'Easter Vigil - Alleluia Psalm': '89',
    }

    specs = [
        ('Easter Vigil - Psalm 1', 'Gen 1:1-2:2', 'Ps 104:1-2, 5-6, 10, 12, 13-14, 24, 35', 'Lord, send out your Spirit, and renew the face of the earth.', 'IN the beginning, when God created the heavens and the earth,'),
        ('Easter Vigil - Psalm 1 (Alt)', 'Gen 1:1-2:2', 'Ps 33:4-5, 6-7, 12-13, 20-22', 'The earth is full of the goodness of the Lord.', 'IN the beginning, when God created the heavens and the earth,'),
        ('Easter Vigil - Psalm 2', 'Gen 22:1-18', 'Ps 16:5, 8, 9-10, 11', 'You are my inheritance, O Lord.', 'GOD put Abraham to the test.'),
        ('Easter Vigil - Psalm 3', 'Exod 14:15-15:1', 'Exod 15:1-2, 3-4, 5-6, 17-18', 'Let us sing to the Lord; he has covered himself in glory.', 'THE LORD said to Moses, “Why are you crying out to me?”'),
        ('Easter Vigil - Psalm 4', 'Isa 54:5-14', 'Ps 30:2, 4, 5-6, 11-12, 13', 'I will praise you, Lord, for you have rescued me.', 'THE One who has become your husband is your Maker;'),
        ('Easter Vigil - Psalm 5', 'Isa 55:1-11', 'Isa 12:2-3, 4, 5-6', 'You will draw water joyfully from the springs of salvation.', 'THUS says the LORD:'),
        ('Easter Vigil - Psalm 5 (Alt)', 'Isa 55:1-11', 'Ps 51:12-13, 14-15, 18-19', 'Create a clean heart in me, O God.', 'THUS says the LORD:'),
        ('Easter Vigil - Psalm 6', 'Bar 3:9-15, 32-4:4', 'Ps 19:8, 9, 10, 11', 'Lord, you have the words of everlasting life.', 'HEAR, O Israel, the commandments of life:'),
        ('Easter Vigil - Psalm 7', 'Ezek 36:16-17a, 18-28', 'Ps 42:3, 5; 43:3, 4', 'Like a deer that longs for running streams, my soul longs for you, my God.', 'THE word of the LORD came to me, saying:'),
        ('Easter Vigil - Alleluia Psalm', 'Rom 6:3-11', 'Ps 118:1-2, 16-17, 22-23', 'Alleluia, alleluia, alleluia.', 'BROTHERS and sisters:'),
    ]

    rows: List[Dict[str, str]] = []
    for title, first_ref, psalm_ref, psalm_response, first_incipit in specs:
        rows.append({
            'season': 'Easter',
            'week': 'Vigil',
            'day': title,
            'weekday_cycle': '',
            'sunday_cycle': 'ABC',
            'reading_cycle': 'ABC',
            'first_reading': clean_reference(first_ref),
            'second_reading': '',
            'psalm_reference': clean_reference(psalm_ref),
            'psalm_response': psalm_response,
            'gospel': clean_reference(gospel),
            'acclamation_ref': acclamation_ref,
            'acclamation_text': acclamation_text,
            'lectionary_number': '',
            'first_reading_incipit': sanitize_incipit(first_incipit),
            'gospel_incipit': '',
            'source_file': 'sunday_readings_columns.txt',
            'source_page': page_map.get(title, ''),
            'source_title': 'Easter Vigil ABC',
            'reference_status': validator_status(first_ref, '', gospel),
            'parser_warnings': '',
        })
    return rows


def sort_key(row: Dict[str, str]) -> Tuple[int, int, int, str, str]:
    season_order = {'Advent': 0, 'Christmas': 1, 'Ordinary Time': 2, 'Lent': 3, 'Holy Week': 4, 'Easter': 5, 'Solemnities': 6}
    day_order = {'Sunday': 0, 'Ash Wednesday': 1, 'Palm Sunday': 2, 'Holy Thursday': 3, 'Good Friday': 4, 'Monday': 5, 'Tuesday': 6, 'Wednesday': 7, 'Thursday': 8, 'Friday': 9, 'Saturday': 10}
    week = row['week']
    return season_order.get(row['season'], 99), int(week) if week.isdigit() else 99, day_order.get(row['day'], 50), row['weekday_cycle'] or row['sunday_cycle'], row['reading_cycle']


def build_rows() -> List[Dict[str, str]]:
    rows = load_weekday_rows() + load_sunday_rows() + load_easter_vigil_rows()
    rows.sort(key=sort_key)
    return rows


def write_rows(rows: List[Dict[str, str]], out_path: Path = OUTPUT_CSV) -> None:
    with out_path.open('w', newline='', encoding='utf-8') as handle:
        writer = csv.DictWriter(handle, fieldnames=FIELDS)
        writer.writeheader()
        for row in rows:
            writer.writerow({field: row.get(field, '') for field in FIELDS})


def audit(rows: List[Dict[str, str]]) -> None:
    print(f'rows={len(rows)}')
    print(f'weekday_rows={sum(1 for row in rows if row["day"] != "Sunday" and not row["sunday_cycle"])}')
    print(f'sunday_rows={sum(1 for row in rows if row["sunday_cycle"])}')
    print(f'grounded_rows={sum(1 for row in rows if row["reference_status"] == "grounded")}')


def main() -> None:
    rows = build_rows()
    write_rows(rows)
    audit(rows)


if __name__ == '__main__':
    main()
