#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
from collections import Counter
from pathlib import Path

from incipit_utils import (
    OfficialIncipitRules,
    VerseCandidate,
    build_incipit_override,
    extract_weekday_lectionary_openings,
    pick_best_opening,
    should_include_official_prefix,
)


DEFAULT_HEADER = [
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


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument('--csv', default='standard_lectionary_complete.csv')
    p.add_argument('--weekday-a', default='scripts/weekday_a_full.txt')
    p.add_argument('--weekday-b', default='scripts/weekday_b_full.txt')
    p.add_argument('--write', action='store_true')
    p.add_argument('--backup-suffix', default='.bak')
    p.add_argument(
        '--prune-redundant',
        action='store_true',
        help='Clear incipit overrides that are redundant with the official incipit',
    )
    p.add_argument('--limit', type=int, default=0, help='Process only N rows (0 = all)')
    return p.parse_args()


def load_csv(path: Path) -> list[list[str]]:
    with path.open('r', encoding='utf-8-sig', newline='') as handle:
        return list(csv.reader(handle))


def ensure_header(rows: list[list[str]]) -> tuple[list[list[str]], dict[str, int]]:
    if not rows:
        raise ValueError('CSV is empty')
    header = [h.strip() for h in rows[0]]
    if header == DEFAULT_HEADER:
        return rows, {name: idx for idx, name in enumerate(header)}

    if header and header[-1].strip() == 'gospel_incipit' and 'first_reading_incipit' not in header:
        # Old format: append the new column before gospel_incipit.
        new_header = header[:-1] + ['first_reading_incipit', 'gospel_incipit']
        migrated = [new_header]
        for row in rows[1:]:
            padded = list(row)
            while len(padded) < len(header):
                padded.append('')
            padded = padded[: len(header)]
            padded = padded[:-1] + [''] + [padded[-1]]
            migrated.append(padded)
        return migrated, {name: idx for idx, name in enumerate(new_header)}

    raise ValueError(f'Unexpected header: {header}')


def merge_openings(
    a: dict[str, dict[str, list[VerseCandidate]]],
    b: dict[str, dict[str, list[VerseCandidate]]],
) -> dict[str, dict[str, list[VerseCandidate]]]:
    merged: dict[str, dict[str, list[VerseCandidate]]] = {}
    for source in (a, b):
        for num, sections in source.items():
            entry = merged.setdefault(num, {'first': [], 'gospel': []})
            for key in ('first', 'gospel'):
                if entry[key]:
                    continue
                if sections.get(key):
                    entry[key] = sections[key]
    return merged


def main() -> int:
    args = parse_args()
    repo_root = Path('.').resolve()
    csv_path = Path(args.csv)

    weekday_a = extract_weekday_lectionary_openings(Path(args.weekday_a))
    weekday_b = extract_weekday_lectionary_openings(Path(args.weekday_b))
    openings_by_number = merge_openings(weekday_a, weekday_b)
    rules = OfficialIncipitRules.load_from_repo(repo_root)

    rows = load_csv(csv_path)
    rows, idx = ensure_header(rows)

    stats: Counter[str] = Counter()
    changed = 0
    processed = 0

    max_rows = args.limit if args.limit and args.limit > 0 else None
    for row_index in range(1, len(rows)):
        if max_rows is not None and processed >= max_rows:
            break
        row = rows[row_index]
        processed += 1

        # Pad.
        if len(row) < len(rows[0]):
            row.extend([''] * (len(rows[0]) - len(row)))
        if len(row) > len(rows[0]):
            row = row[: len(rows[0])]
            rows[row_index] = row

        lectionary_number = (row[idx['lectionary_number']] or '').strip()
        if not lectionary_number:
            stats['skip:no_lectionary_number'] += 1
            continue

        openings = openings_by_number.get(lectionary_number)
        if not openings:
            stats['skip:no_openings_for_number'] += 1
            continue

        # First reading
        ref = (row[idx['first_reading']] or '').strip()
        official = rules.get_official_incipit(ref)
        candidate = pick_best_opening(openings.get('first') or [], is_gospel=False)
        existing_first = (row[idx['first_reading_incipit']] or '').strip()
        if args.prune_redundant and existing_first and official and candidate:
            recomputed = build_incipit_override(
                official_incipit=official,
                verse=candidate.verse,
                opening_sentence=candidate.text,
            )
            if recomputed is None:
                row[idx['first_reading_incipit']] = ''
                changed += 1
                stats['pruned:first_reading'] += 1
        elif not existing_first:
            if candidate:
                if should_include_official_prefix(official, is_gospel=False) and official:
                    inc = build_incipit_override(
                        official_incipit=official,
                        verse=candidate.verse,
                        opening_sentence=candidate.text,
                    )
                    if inc:
                        row[idx['first_reading_incipit']] = inc
                        changed += 1
                        stats['filled:first_reading'] += 1
                    else:
                        stats['skip:first_reading_no_override'] += 1
                else:
                    # No official prefix: store the missal's opening sentence only
                    # (backend will preserve verse prefix from the Bible DB line).
                    row[idx['first_reading_incipit']] = candidate.text
                    changed += 1
                    stats['filled:first_reading_opening_only'] += 1
            else:
                stats['skip:first_reading_missing'] += 1

        # Gospel
        ref = (row[idx['gospel']] or '').strip()
        official = rules.get_official_incipit(ref)
        candidate = pick_best_opening(openings.get('gospel') or [], is_gospel=True)
        existing_gospel = (row[idx['gospel_incipit']] or '').strip()
        if args.prune_redundant and existing_gospel and official and candidate:
            recomputed = build_incipit_override(
                official_incipit=official,
                verse=candidate.verse,
                opening_sentence=candidate.text,
            )
            if recomputed is None:
                row[idx['gospel_incipit']] = ''
                changed += 1
                stats['pruned:gospel'] += 1
        elif not existing_gospel:
            if official and candidate:
                inc = build_incipit_override(
                    official_incipit=official,
                    verse=candidate.verse,
                    opening_sentence=candidate.text,
                )
                if inc:
                    row[idx['gospel_incipit']] = inc
                    changed += 1
                    stats['filled:gospel'] += 1
                else:
                    stats['skip:gospel_no_override'] += 1
            else:
                stats['skip:gospel_missing'] += 1

    print(f'Rows scanned: {processed}')
    print(f'Cells filled: {changed}')
    if stats:
        print('Summary:')
        for k, v in stats.most_common():
            print(f'  {k}: {v}')

    if not args.write:
        print('Dry run only. Re-run with --write to apply.')
        return 0

    backup_path = csv_path.with_name(csv_path.name + args.backup_suffix)
    backup_path.write_text(csv_path.read_text(encoding='utf-8-sig'), encoding='utf-8')
    with csv_path.open('w', encoding='utf-8', newline='') as handle:
        writer = csv.writer(handle)
        writer.writerows(rows)
    print(f'Wrote updated CSV to {csv_path}')
    print(f'Backup saved to {backup_path}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
