#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import re
from collections import Counter
from pathlib import Path

HEADER = [
    'season',
    'week',
    'day',
    'weekday_cycle',
    'sunday_cycle',
    'reading_cycle',
    'first_reading',
    'second_reading',
    'psalm_reference',
    'psalm_response',
    'gospel',
    'acclamation_ref',
    'acclamation_text',
    'lectionary_number',
    'first_reading_incipit',
    'gospel_incipit',
]

BOOK_REPLACEMENTS = [
    ('2 Samuel', '2 Sam'),
    ('1 Samuel', '1 Sam'),
    ('Isaiah', 'Isa'),
    ('Jeremiah', 'Jer'),
    ('Zephaniah', 'Zeph'),
    ('Malachi', 'Mal'),
    ('Genesis', 'Gen'),
    ('Exodus', 'Exod'),
    ('Numbers', 'Num'),
    ('Deuteronomy', 'Deut'),
    ('Micah', 'Mic'),
    ('Daniel', 'Dan'),
    ('Hosea', 'Hos'),
    ('Wisdom', 'Wis'),
    ('Matthew', 'Matt'),
    ('Mark', 'Mark'),
    ('Luke', 'Luke'),
    ('John', 'John'),
    ('Romans', 'Rom'),
    ('Philippians', 'Phil'),
    ('Hebrews', 'Heb'),
    ('Baruch', 'Bar'),
    ('Psalm', 'Ps'),
    ('Psalms', 'Ps'),
]

REFERENCE_FIELDS = {
    'first_reading',
    'second_reading',
    'psalm_reference',
    'gospel',
    'acclamation_ref',
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument('--csv', default='standard_lectionary_complete.csv')
    parser.add_argument('--write', action='store_true')
    parser.add_argument('--backup-suffix', default='.bak')
    return parser.parse_args()


def load_rows(path: Path) -> list[list[str]]:
    with path.open('r', encoding='utf-8-sig', newline='') as handle:
        return list(csv.reader(handle))


def fix_column_count(row: list[str]) -> tuple[list[str], list[str]]:
    changes: list[str] = []
    values = list(row)
    if len(values) < len(HEADER):
        values.extend([''] * (len(HEADER) - len(values)))
        changes.append('padded_missing_columns')
    elif len(values) > len(HEADER):
        overflow = values[len(HEADER) - 1 :]
        values = values[: len(HEADER) - 1] + [','.join(overflow).strip()]
        changes.append('merged_overflow_into_gospel_incipit')
    return values, changes


def normalize_shorter_prefix(value: str) -> tuple[str, bool]:
    normalized = re.sub(
        r'^\(\s*s\s*h\s*o\s*r\s*t?\s*e\s*r\s*\)\s*',
        '',
        value,
        flags=re.IGNORECASE,
    )
    normalized = re.sub(r'^\(\s*shorter\s*\)\s*', '', normalized, flags=re.IGNORECASE)
    return normalized, normalized != value


def normalize_reference(value: str) -> tuple[str, list[str]]:
    result = value.strip()
    if not result:
        return result, []

    changes: list[str] = []
    shorter_fixed, changed = normalize_shorter_prefix(result)
    if changed:
        result = shorter_fixed
        changes.append('removed_shorter_prefix')

    cycle_ref = re.match(r'^(.*?)\s*\(([ABC])\);\s*(.*)$', result)
    if cycle_ref:
        result = cycle_ref.group(1).strip()
        changes.append('trimmed_cycle_suffix')

    for old, new in BOOK_REPLACEMENTS:
        updated = result.replace(old, new)
        if updated != result:
            result = updated
            changes.append(f'book:{old}->{new}')

    updated = re.sub(r'^([A-Za-z0-9 ]+\s\d+)\.\s*(\d)', r'\1:\2', result)
    if updated != result:
        result = updated
        changes.append('normalized_chapter_separator')

    updated = re.sub(r'\s+or\s+.+$', '', result, flags=re.IGNORECASE)
    if updated != result:
        result = updated.strip()
        changes.append('removed_or_clause')

    updated = re.sub(r'\s*\(R\.[^)]+\)$', '', result, flags=re.IGNORECASE)
    if updated != result:
        result = updated.strip()
        changes.append('removed_refrain_suffix')

    updated = re.sub(r'\s+', ' ', result).strip()
    if updated != result:
        result = updated
        changes.append('collapsed_whitespace')

    return result, changes


def normalize_general(value: str) -> tuple[str, list[str]]:
    result = value.strip()
    updated = re.sub(r'\s+', ' ', result).strip()
    if updated != result:
        return updated, ['collapsed_whitespace']
    return result, []


def normalize_row(row: list[str]) -> tuple[list[str], list[str]]:
    fixed_row, changes = fix_column_count(row)
    normalized = list(fixed_row)

    # Repair a common formatting issue where the final empty column was omitted
    # and the lectionary number slid into the last field.
    lectionary_index = HEADER.index('lectionary_number')
    first_incipit_index = HEADER.index('first_reading_incipit')
    gospel_incipit_index = HEADER.index('gospel_incipit')
    if (
        not normalized[lectionary_index].strip()
        and not normalized[first_incipit_index].strip()
        and normalized[gospel_incipit_index].strip().isdigit()
    ):
        normalized[lectionary_index] = normalized[gospel_incipit_index].strip()
        normalized[gospel_incipit_index] = ''
        changes.append('moved_numeric_gospel_incipit_to_lectionary_number')

    for index, field in enumerate(HEADER):
        value = normalized[index]
        if field in REFERENCE_FIELDS:
            updated, field_changes = normalize_reference(value)
        else:
            updated, field_changes = normalize_general(value)
        normalized[index] = updated
        changes.extend(f'{field}:{change}' for change in field_changes)

    return normalized, changes


def write_rows(path: Path, rows: list[list[str]]) -> None:
    with path.open('w', encoding='utf-8', newline='') as handle:
        writer = csv.writer(handle)
        writer.writerows(rows)


def main() -> int:
    args = parse_args()
    csv_path = Path(args.csv)
    rows = load_rows(csv_path)
    if not rows:
        print('CSV is empty')
        return 1

    header = rows[0]
    data = rows[1:]
    normalized_header = [value.strip() for value in header[: len(HEADER)]]
    if normalized_header != HEADER:
        print('Unexpected header; aborting to avoid destructive rewrite.')
        print('Found:', header)
        return 1

    normalized_rows = [HEADER]
    changed_rows: list[tuple[int, list[str]]] = []
    change_counter: Counter[str] = Counter()

    for idx, row in enumerate(data, start=2):
        normalized, changes = normalize_row(row)
        normalized_rows.append(normalized)
        if normalized != row[: len(normalized)] or len(row) != len(normalized):
            changed_rows.append((idx, changes))
            change_counter.update(changes)

    print(f'Rows scanned: {len(data)}')
    print(f'Rows changed: {len(changed_rows)}')
    if change_counter:
        print('Change summary:')
        for key, count in change_counter.most_common():
            print(f'  {key}: {count}')

    if changed_rows:
        print('Sample changed rows:')
        for line_no, changes in changed_rows[:25]:
            print(f'  line {line_no}: {", ".join(changes)}')

    if not args.write:
        print('Dry run only. Re-run with --write to apply.')
        return 0

    backup_path = csv_path.with_name(csv_path.name + args.backup_suffix)
    backup_path.write_text(csv_path.read_text(encoding='utf-8-sig'), encoding='utf-8')
    write_rows(csv_path, normalized_rows)
    print(f'Wrote cleaned CSV to {csv_path}')
    print(f'Backup saved to {backup_path}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
