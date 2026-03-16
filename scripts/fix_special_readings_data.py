import json
import shutil
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DB_PATH = ROOT / 'assets' / 'readings.db'
JSON_PATH = ROOT / 'assets' / 'data' / 'readings_rows.json'
DB_BACKUP_PATH = ROOT / 'assets' / 'readings.db.special_days.bak'
JSON_BACKUP_PATH = ROOT / 'assets' / 'data' / 'readings_rows.json.special_days.bak'

PALM_SUNDAY_PASSION_GOSPELS = {
    'Matt 26:14-27:66',
    'Mark 14:1-15:47',
    'Luke 22:14-23:56',
}
PALM_SUNDAY_ENTRY_GOSPELS = {
    'Matt 21:1-11',
    'Mark 11:1-10',
    'Luke 19:28-40',
    'John 12:12-16',
}
PALM_SUNDAY_ACCLAMATIONS = {
    'Phil 2:8-9',
}
EASTER_VIGIL_PRIMARY_ORDER = [
    'Gen 1:1-2:2',
    'Ps 104:1-35',
    'Gen 22:1-18',
    'Ps 16:5-11',
    'Exod 14:15-15:1',
    'Exod 15:1-18',
    'Isa 54:5-14',
    'Ps 30:1-13',
    'Isa 55:1-11',
    'Isa 12:1-6',
    'Bar 3:9-15, 32-4:4',
    'Ps 19:8-11',
    'Ezek 36:16-28',
    'Ps 42:3-5, 43:3-4',
    'Rom 6:3-11',
    'Ps 118:1-23',
]
EASTER_VIGIL_ALT_ROWS = {
    'Ps 33:4-22',
    'Ps 51:12-19',
}
ST_STEPHEN_FIRST_READING = 'Acts 6:8-10'
ST_STEPHEN_CONTINUATION = '7:54-59'
ST_STEPHEN_MERGED = 'Acts 6:8-10; 7:54-59'


def is_psalm_like(reference: str) -> bool:
    normalized = reference.strip().lower()
    return (
        normalized.startswith('ps ')
        or normalized.startswith('psalm ')
        or normalized.startswith('isa 12')
        or normalized.startswith('exod 15')
        or normalized.startswith('1 sam 2')
        or normalized.startswith('luke 1:')
    )


def is_gospel(reference: str) -> bool:
    normalized = reference.strip().lower()
    return (
        normalized.startswith('matt ')
        or normalized.startswith('mark ')
        or normalized.startswith('luke ')
        or normalized.startswith('john ')
    )


def clean_row_fields(row: dict) -> dict:
    updated = dict(row)
    if not is_psalm_like(updated['reading']):
        updated['psalm_response'] = None
        updated['psalm_response_alternatives'] = None
        updated['psalm_response_cache_key'] = None
    if not is_gospel(updated['reading']):
        updated['gospel_acclamation'] = None
        updated['gospel_acclamation_cache_key'] = None
    return updated


def backup_file(path: Path, backup_path: Path) -> None:
    if not backup_path.exists():
        shutil.copy2(path, backup_path)


def _retired() -> int:
    print(
        'This legacy patch script is retired. '
        'Special-day data now lives in standard_lectionary_complete.csv and memorial_feasts.csv.'
    )
    return 1


def load_json_rows() -> list[dict]:
    return json.loads(JSON_PATH.read_text(encoding='utf-8-sig'))


def save_json_rows(rows: list[dict]) -> None:
    JSON_PATH.write_text(json.dumps(rows, ensure_ascii=False), encoding='utf-8')


def is_palm_sunday(rows: list[dict]) -> bool:
    readings = {row['reading'] for row in rows}
    return any(ref in readings for ref in PALM_SUNDAY_PASSION_GOSPELS) and 'Isa 50:4-7' in readings


def is_easter_vigil(rows: list[dict]) -> bool:
    readings = {row['reading'] for row in rows}
    return 'Rom 6:3-11' in readings and 'Ps 118:1-23' in readings and any(
        gospel in readings for gospel in ('Matt 28:1-10', 'Mark 16:1-7', 'Luke 24:1-12')
    )


def is_st_stephen(rows: list[dict]) -> bool:
    readings = {row['reading'] for row in rows}
    return ST_STEPHEN_FIRST_READING in readings and ST_STEPHEN_CONTINUATION in readings


def fix_palm_sunday(rows: list[dict]) -> list[dict]:
    entry_gospels = [row for row in rows if row['reading'] in PALM_SUNDAY_ENTRY_GOSPELS]
    first_entry = entry_gospels[0] if entry_gospels else None
    passion = next((row for row in rows if row['reading'] in PALM_SUNDAY_PASSION_GOSPELS), None)
    first_reading = next((row for row in rows if row['reading'] == 'Isa 50:4-7'), None)
    psalm = next((row for row in rows if row['reading'].startswith('Ps 22:')), None)
    second_reading = next((row for row in rows if row['reading'] == 'Phil 2:6-11'), None)

    ordered = [item for item in [first_entry, first_reading, psalm, second_reading, passion] if item is not None]
    result = []
    for index, row in enumerate(ordered, start=1):
        updated = clean_row_fields(row)
        updated['position'] = index
        result.append(updated)
    return result


def fix_easter_vigil(rows: list[dict]) -> list[dict]:
    by_reading = {row['reading']: dict(row) for row in rows}
    gospel = next(
        (
            row for row in rows
            if row['reading'] in {'Matt 28:1-10', 'Mark 16:1-7', 'Luke 24:1-12'}
        ),
        None,
    )

    ordered = []
    for reading in EASTER_VIGIL_PRIMARY_ORDER:
        row = by_reading.get(reading)
        if row is not None:
            ordered.append(row)

    if gospel is not None:
        ordered.append(clean_row_fields(gospel))

    result = []
    for index, row in enumerate(ordered, start=1):
        updated = clean_row_fields(row)
        updated['position'] = index
        result.append(updated)
    return result


def fix_st_stephen(rows: list[dict]) -> list[dict]:
    result = []
    for row in rows:
        if row['reading'] == ST_STEPHEN_CONTINUATION:
            continue
        updated = clean_row_fields(row)
        if updated['reading'] == ST_STEPHEN_FIRST_READING:
            updated['reading'] = ST_STEPHEN_MERGED
        result.append(updated)

    result.sort(key=lambda row: row['position'])
    for index, row in enumerate(result, start=1):
        row['position'] = index
    return result


def normalize_day_rows(rows: list[dict]) -> list[dict]:
    rows = [clean_row_fields(row) for row in sorted(rows, key=lambda row: row['position'])]

    if is_palm_sunday(rows):
        rows = fix_palm_sunday(rows)
    elif is_easter_vigil(rows):
        rows = fix_easter_vigil(rows)
    elif is_st_stephen(rows):
        rows = fix_st_stephen(rows)

    return rows


def patch_json() -> None:
    rows = load_json_rows()
    by_timestamp: dict[int, list[dict]] = {}
    for row in rows:
        by_timestamp.setdefault(int(row['timestamp']), []).append(dict(row))

    rewritten: list[dict] = []
    for timestamp in sorted(by_timestamp):
        rewritten.extend(normalize_day_rows(by_timestamp[timestamp]))

    save_json_rows(rewritten)


def patch_db() -> None:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()

    timestamps = [row[0] for row in cur.execute('SELECT DISTINCT timestamp FROM readings ORDER BY timestamp')]

    for timestamp in timestamps:
        rows = [dict(row) for row in cur.execute(
            'SELECT timestamp, reading, position, psalm_response, psalm_response_alternatives, psalm_response_cache_key, gospel_acclamation, gospel_acclamation_cache_key FROM readings WHERE timestamp = ? ORDER BY position',
            (timestamp,),
        )]
        normalized = normalize_day_rows(rows)
        if normalized == rows:
            continue

        cur.execute('DELETE FROM readings WHERE timestamp = ?', (timestamp,))
        for row in normalized:
            cur.execute(
                '''
                INSERT INTO readings (
                  timestamp,
                  reading,
                  position,
                  psalm_response,
                  psalm_response_alternatives,
                  psalm_response_cache_key,
                  gospel_acclamation,
                  gospel_acclamation_cache_key
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ''',
                (
                    row['timestamp'],
                    row['reading'],
                    row['position'],
                    row.get('psalm_response'),
                    row.get('psalm_response_alternatives'),
                    row.get('psalm_response_cache_key'),
                    row.get('gospel_acclamation'),
                    row.get('gospel_acclamation_cache_key'),
                ),
            )
if __name__ == '__main__':
    raise SystemExit(_retired())
