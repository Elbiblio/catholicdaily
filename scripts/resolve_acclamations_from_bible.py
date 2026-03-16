#!/usr/bin/env python3
"""
Resolve acclamation texts from verses_rows.json Bible data.

Reads standard_lectionary_complete.csv, finds rows with acclamation_ref values,
looks up the actual verse text from verses_rows.json, and patches truncated or
missing acclamation_text entries.

Usage:
  python scripts/resolve_acclamations_from_bible.py            # dry-run
  python scripts/resolve_acclamations_from_bible.py --write    # apply changes
"""
from __future__ import annotations

import argparse
import csv
import json
import re
from collections import defaultdict
from pathlib import Path


# Map CSV book names to verses_rows.json shortnames
# Map CSV book names (lowercased) to verses_rows.json shortnames
BOOK_TO_SHORT = {
    'genesis': 'Gen', 'gen': 'Gen', 'gn': 'Gen',
    'exodus': 'Exod', 'exod': 'Exod', 'ex': 'Exod',
    'leviticus': 'Lev', 'lev': 'Lev', 'lv': 'Lev',
    'numbers': 'Num', 'num': 'Num', 'nm': 'Num',
    'deuteronomy': 'Deut', 'deut': 'Deut', 'dt': 'Deut',
    'joshua': 'Josh', 'josh': 'Josh', 'jos': 'Josh',
    'judges': 'Judg', 'judg': 'Judg', 'jgs': 'Judg',
    'ruth': 'Ruth',
    '1 samuel': '1 Sam', '1 sam': '1 Sam', '1 sm': '1 Sam',
    '2 samuel': '2 Sam', '2 sam': '2 Sam', '2 sm': '2 Sam',
    '1 kings': '1 Kgs', '1 kgs': '1 Kgs',
    '2 kings': '2 Kgs', '2 kgs': '2 Kgs',
    '1 chronicles': '1 Chr', '1 chr': '1 Chr',
    '2 chronicles': '2 Chr', '2 chr': '2 Chr',
    'ezra': 'Ezra',
    'nehemiah': 'Neh', 'neh': 'Neh',
    'tobit': 'Tob', 'tob': 'Tob',
    'judith': 'Jud', 'jdt': 'Jud', 'jud': 'Jud',
    'esther': 'Esth', 'esth': 'Esth',
    '1 maccabees': '1 Macc', '1 macc': '1 Macc',
    '2 maccabees': '2 Macc', '2 macc': '2 Macc',
    'job': 'Job', 'jb': 'Job',
    'psalms': 'Ps', 'psalm': 'Ps', 'ps': 'Ps',
    'proverbs': 'Prov', 'prov': 'Prov', 'prv': 'Prov',
    'ecclesiastes': 'Eccles', 'eccles': 'Eccles', 'eccl': 'Eccles', 'qoh': 'Eccles',
    'song of songs': 'Song', 'song': 'Song', 'sg': 'Song',
    'wisdom': 'Wis', 'wis': 'Wis',
    'sirach': 'Sir', 'sir': 'Sir',
    'isaiah': 'Isa', 'isa': 'Isa', 'is': 'Isa',
    'jeremiah': 'Jer', 'jer': 'Jer',
    'lamentations': 'Lam', 'lam': 'Lam',
    'baruch': 'Bar', 'bar': 'Bar',
    'ezekiel': 'Ezek', 'ezek': 'Ezek', 'ez': 'Ezek',
    'daniel': 'Dan', 'dan': 'Dan',
    'hosea': 'Hos', 'hos': 'Hos',
    'joel': 'Joel', 'jl': 'Joel',
    'amos': 'Amos', 'am': 'Amos',
    'obadiah': 'Obad', 'obad': 'Obad',
    'jonah': 'Jonah', 'jon': 'Jonah',
    'micah': 'Mic', 'mic': 'Mic',
    'nahum': 'Nah', 'nah': 'Nah',
    'habakkuk': 'Hab', 'hab': 'Hab',
    'zephaniah': 'Zeph', 'zeph': 'Zeph',
    'haggai': 'Hagg', 'hag': 'Hagg', 'hagg': 'Hagg',
    'zechariah': 'Zech', 'zech': 'Zech',
    'malachi': 'Mal', 'mal': 'Mal',
    'matthew': 'Matt', 'matt': 'Matt', 'mt': 'Matt',
    'mark': 'Mark', 'mk': 'Mark',
    'luke': 'Luke', 'lk': 'Luke',
    'john': 'John', 'jn': 'John',
    'acts': 'Acts', 'act': 'Acts',
    'romans': 'Rom', 'rom': 'Rom',
    '1 corinthians': '1 Cor', '1 cor': '1 Cor',
    '2 corinthians': '2 Cor', '2 cor': '2 Cor',
    'galatians': 'Gal', 'gal': 'Gal',
    'ephesians': 'Eph', 'eph': 'Eph',
    'philippians': 'Phil', 'phil': 'Phil',
    'colossians': 'Col', 'col': 'Col',
    '1 thessalonians': '1 Thess', '1 thess': '1 Thess', '1 thes': '1 Thess',
    '2 thessalonians': '2 Thess', '2 thess': '2 Thess', '2 thes': '2 Thess',
    '1 timothy': '1 Tim', '1 tim': '1 Tim',
    '2 timothy': '2 Tim', '2 tim': '2 Tim',
    'titus': 'Titus',
    'philemon': 'Phlm', 'phlm': 'Phlm',
    'hebrews': 'Heb', 'heb': 'Heb',
    'james': 'James', 'jas': 'James',
    '1 peter': '1 Pet', '1 pet': '1 Pet',
    '2 peter': '2 Pet', '2 pet': '2 Pet',
    '1 john': '1 John', '1 jn': '1 John',
    '2 john': '2 John', '2 jn': '2 John',
    '3 john': '3 John', '3 jn': '3 John',
    'jude': 'Jude',
    'revelation': 'Rev', 'rev': 'Rev', 'rv': 'Rev',
    'apocalypse': 'Rev',
}


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument('--csv', default='standard_lectionary_complete.csv')
    p.add_argument('--verses', default='assets/data/verses_rows.json')
    p.add_argument('--write', action='store_true')
    return p.parse_args()


def load_verses(path: Path) -> dict[tuple[str, int, int], str]:
    """Load verses_rows.json into a (shortname, chapter, verse) -> text map."""
    raw = json.loads(path.read_text(encoding='utf-8-sig'))
    lookup: dict[tuple[str, int, int], str] = {}
    for row in raw:
        sn = row.get('shortname', '')
        ch = row.get('chapter_id')
        v = row.get('verse_id')
        txt = row.get('text', '')
        if sn and ch is not None and v is not None:
            lookup[(sn, int(ch), int(v))] = txt
    return lookup


def _resolve_book(text: str) -> str | None:
    """Try progressively shorter prefixes to find a book shortname."""
    words = text.split()
    # Try longest prefix first (up to 3 words: "1 Samuel", "Song of Songs")
    for length in range(min(3, len(words)), 0, -1):
        candidate = ' '.join(words[:length]).lower()
        if candidate in BOOK_TO_SHORT:
            return candidate
    return None


def parse_ref(ref_str: str) -> list[tuple[str, int, int, str | None]]:
    """Parse an acclamation_ref like 'Isaiah 55.6' or 'John 6.63c, 68c'
    into [(shortname, chapter, verse, part_letter|None), ...].

    Also handles semicolon-joined multi-book refs like
    '1 Samuel 3:9; John 6:68c'.
    """
    ref = ref_str.strip()
    # Strip leading See/Cf.
    ref = re.sub(r'^(?:See\s+|Cf\.?\s+)', '', ref, flags=re.IGNORECASE).strip()
    if not ref:
        return []

    # Handle semicolon-separated multi-book refs
    if ';' in ref:
        results: list[tuple[str, int, int, str | None]] = []
        for part in ref.split(';'):
            results.extend(parse_ref(part.strip()))
        return results

    # Find the book name
    book_key = _resolve_book(ref)
    if not book_key:
        return []

    shortname = BOOK_TO_SHORT[book_key]
    rest = ref[len(book_key):].strip()

    results = []

    # Parse chapter:verse or chapter.verse patterns
    # Normalize separator: treat both : and . as chapter-verse separator
    ch_match = re.match(r'(\d+)\s*[:.;,]\s*(.+)', rest)
    if not ch_match:
        return []

    chapter = int(ch_match.group(1))
    verse_part = ch_match.group(2).strip()

    # Split on comma for multiple verses
    segments = verse_part.split(',')
    for seg in segments:
        seg = seg.strip()
        if not seg:
            continue
        # Handle range like 12-13
        if '-' in seg:
            range_parts = seg.split('-')
            start_m = re.match(r'(\d+)([a-d]*)', range_parts[0].strip())
            end_m = re.match(r'(\d+)([a-d]*)', range_parts[1].strip())
            if start_m and end_m:
                sv = int(start_m.group(1))
                ev = int(end_m.group(1))
                sp = start_m.group(2) or None
                ep = end_m.group(2) or None
                if sv == ev:
                    results.append((shortname, chapter, sv, sp))
                else:
                    results.append((shortname, chapter, sv, sp))
                    for v in range(sv + 1, ev):
                        results.append((shortname, chapter, v, None))
                    results.append((shortname, chapter, ev, ep))
        else:
            m = re.match(r'(\d+)([a-d]*)', seg)
            if m:
                v = int(m.group(1))
                part = m.group(2) or None
                results.append((shortname, chapter, v, part))

    return results


def clean_verse_text(text: str) -> str:
    """Remove verse number prefix and clean up text."""
    text = re.sub(r'^\d+\.\s*', '', text)  # remove "6. " prefix
    text = re.sub(r'^"', '', text)  # remove leading quote
    text = re.sub(r'"$', '', text)  # remove trailing quote
    return text.strip()


def extract_part(text: str, part: str | None) -> str:
    """Extract a lettered sub-part from a verse. Crude but functional."""
    if not part:
        return text

    # Split on semicolons and major punctuation for parts
    # a = first clause, b = second, etc.
    parts = re.split(r'[;]', text)
    if not parts:
        return text

    idx = ord(part[0]) - ord('a')
    if 0 <= idx < len(parts):
        result = parts[idx].strip()
        # If multi-letter part like 'bc', join multiple
        if len(part) > 1:
            end_idx = ord(part[-1]) - ord('a')
            result = '; '.join(p.strip() for p in parts[idx:end_idx + 1] if p.strip())
        return result

    return text


def resolve_acclamation(
    ref_str: str,
    verses: dict[tuple[str, int, int], str],
) -> str | None:
    """Resolve an acclamation_ref to its full text from the Bible."""
    parsed = parse_ref(ref_str)
    if not parsed:
        return None

    text_parts: list[str] = []
    for shortname, chapter, verse, part in parsed:
        raw = verses.get((shortname, chapter, verse))
        if raw is None:
            # Try alternate shortname patterns
            for alt_key, alt_val in verses.items():
                if alt_key[1] == chapter and alt_key[2] == verse and alt_key[0].lower() == shortname.lower():
                    raw = alt_val
                    break
        if raw is None:
            continue

        cleaned = clean_verse_text(raw)
        if part:
            cleaned = extract_part(cleaned, part)
        text_parts.append(cleaned)

    if not text_parts:
        return None

    full = ' '.join(text_parts)
    # Clean up trailing/leading punctuation
    full = full.strip().rstrip(',;')
    if not full.endswith(('.', '!', '?', ':')):
        full += '.'
    return full


def looks_truncated(text: str) -> bool:
    """Check if acclamation_text looks incomplete."""
    text = text.strip()
    if not text:
        return True
    if len(text) < 25:
        return True

    incomplete = (
        ' while he', ' that i', ' that you', ' and the', ' and he',
        ' and i', ' for the', ' for i', ' for you', ' to the',
        ' to me', ' to you', ' of the', ' in the', ' with the',
        ' so that', ' who has', ' who is', ' but on',
    )
    lower = text.lower()
    if any(lower.endswith(e) for e in incomplete):
        return True

    if not text.endswith(('.', '!', '?', ':', '"')):
        if len(text) < 55:
            return True

    return False


def main() -> int:
    args = parse_args()
    root = Path(__file__).resolve().parents[1]
    csv_path = root / args.csv
    verses_path = root / args.verses

    print(f'Loading verses from {verses_path.name}...')
    verses = load_verses(verses_path)
    print(f'  Loaded {len(verses)} verses')

    with csv_path.open(encoding='utf-8-sig', newline='') as f:
        rows = list(csv.DictReader(f))
        fieldnames = list(rows[0].keys()) if rows else []

    # Phase 1: Collect all unique acclamation_ref values and resolve them
    unique_refs: dict[str, str | None] = {}
    for row in rows:
        ref = row.get('acclamation_ref', '').strip()
        if ref and ref not in unique_refs:
            resolved = resolve_acclamation(ref, verses)
            unique_refs[ref] = resolved

    resolved_count = sum(1 for v in unique_refs.values() if v)
    print(f'\nUnique acclamation_ref values: {len(unique_refs)}')
    print(f'Successfully resolved from Bible: {resolved_count}')
    print(f'Could not resolve: {len(unique_refs) - resolved_count}')

    # Show unresolved
    unresolved = [r for r, v in unique_refs.items() if not v]
    if unresolved:
        print('\nUnresolved refs:')
        for r in sorted(unresolved):
            print(f'  {r}')

    # Phase 2: Find rows that need patching
    patches: list[tuple[int, dict[str, str], str]] = []
    for idx, row in enumerate(rows):
        ref = row.get('acclamation_ref', '').strip()
        current_text = row.get('acclamation_text', '').strip()
        if not ref:
            continue

        resolved = unique_refs.get(ref)
        if not resolved:
            continue

        if not looks_truncated(current_text):
            continue

        # Only patch if resolved text is meaningfully longer
        if current_text and len(resolved) <= len(current_text) + 5:
            continue

        patches.append((idx, row, resolved))

    print(f'\nRows needing patch: {len(patches)}')

    for idx, row, new_text in patches:
        season = row.get('season', '')
        week = row.get('week', '')
        day = row.get('day', '')
        ref = row.get('acclamation_ref', '')
        old_text = row.get('acclamation_text', '')
        print(
            f'\n[{idx + 2}] {season} | {week} | {day}'
            f'\n  ref: {ref}'
            f'\n  old: {old_text!r}'
            f'\n  new: {new_text!r}'
        )

    if not args.write:
        print('\nDry run complete. Use --write to apply changes.')
        return 0

    for idx, row, new_text in patches:
        row['acclamation_text'] = new_text
        rows[idx] = row

    with csv_path.open('w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f'\nPatched {len(patches)} rows in {csv_path.name}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
