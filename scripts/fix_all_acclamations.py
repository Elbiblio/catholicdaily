#!/usr/bin/env python3
"""
Comprehensive acclamation fix script.

Strategy:
1. Find all truncated/incomplete acclamation_text rows
2. Try to resolve from sibling cycle rows (same lectionary_number, different cycle)
3. Try to resolve from Bible verses_rows.json for direct-quote refs
4. Report remaining gaps for manual review

Usage:
  python scripts/fix_all_acclamations.py            # dry-run
  python scripts/fix_all_acclamations.py --write    # apply
"""
from __future__ import annotations

import argparse
import csv
import json
import re
from collections import defaultdict
from pathlib import Path


BOOK_TO_SHORT = {
    'genesis': 'Gen', 'gen': 'Gen', 'gn': 'Gen',
    'exodus': 'Exod', 'exod': 'Exod', 'ex': 'Exod',
    'leviticus': 'Lev', 'lev': 'Lev',
    'numbers': 'Num', 'num': 'Num',
    'deuteronomy': 'Deut', 'deut': 'Deut',
    'joshua': 'Josh', 'josh': 'Josh',
    'judges': 'Judg', 'judg': 'Judg',
    'ruth': 'Ruth',
    '1 samuel': '1 Sam', '1 sam': '1 Sam',
    '2 samuel': '2 Sam', '2 sam': '2 Sam',
    '1 kings': '1 Kgs', '1 kgs': '1 Kgs',
    '2 kings': '2 Kgs', '2 kgs': '2 Kgs',
    '1 chronicles': '1 Chr', '1 chr': '1 Chr',
    '2 chronicles': '2 Chr', '2 chr': '2 Chr',
    'ezra': 'Ezra', 'nehemiah': 'Neh', 'neh': 'Neh',
    'tobit': 'Tob', 'tob': 'Tob',
    'judith': 'Jud', 'jud': 'Jud',
    'esther': 'Esth', 'esth': 'Esth',
    '1 maccabees': '1 Macc', '1 macc': '1 Macc',
    '2 maccabees': '2 Macc', '2 macc': '2 Macc',
    'job': 'Job', 'jb': 'Job',
    'psalms': 'Ps', 'psalm': 'Ps', 'ps': 'Ps',
    'proverbs': 'Prov', 'prov': 'Prov',
    'ecclesiastes': 'Eccles', 'eccles': 'Eccles',
    'song of songs': 'Song', 'song': 'Song',
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
    '1 thessalonians': '1 Thess', '1 thess': '1 Thess',
    '2 thessalonians': '2 Thess', '2 thess': '2 Thess',
    '1 timothy': '1 Tim', '1 tim': '1 Tim',
    '2 timothy': '2 Tim', '2 tim': '2 Tim',
    'titus': 'Titus', 'philemon': 'Phlm', 'phlm': 'Phlm',
    'hebrews': 'Heb', 'heb': 'Heb',
    'james': 'James', 'jas': 'James',
    '1 peter': '1 Pet', '1 pet': '1 Pet',
    '2 peter': '2 Pet', '2 pet': '2 Pet',
    '1 john': '1 John', '1 jn': '1 John',
    '2 john': '2 John', '3 john': '3 John',
    'jude': 'Jude',
    'revelation': 'Rev', 'rev': 'Rev', 'apocalypse': 'Rev',
}


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument('--csv', default='standard_lectionary_complete.csv')
    p.add_argument('--verses', default='assets/data/verses_rows.json')
    p.add_argument('--write', action='store_true')
    return p.parse_args()


def load_verses(path: Path) -> dict[tuple[str, int, int], str]:
    raw = json.loads(path.read_text(encoding='utf-8-sig'))
    return {
        (r['shortname'], int(r['chapter_id']), int(r['verse_id'])): r['text']
        for r in raw if r.get('shortname') and r.get('chapter_id') is not None
    }


def _resolve_book(text: str) -> str | None:
    words = text.split()
    for length in range(min(3, len(words)), 0, -1):
        candidate = ' '.join(words[:length]).lower()
        if candidate in BOOK_TO_SHORT:
            return candidate
    return None


def parse_ref(ref_str: str) -> list[tuple[str, int, int, str | None]]:
    ref = re.sub(r'^(?:See\s+|Cf\.?\s+)', '', ref_str.strip(), flags=re.IGNORECASE).strip()
    if not ref:
        return []

    if ';' in ref:
        results = []
        for part in ref.split(';'):
            results.extend(parse_ref(part.strip()))
        return results

    book_key = _resolve_book(ref)
    if not book_key:
        return []

    shortname = BOOK_TO_SHORT[book_key]
    rest = ref[len(book_key):].strip()

    ch_match = re.match(r'(\d+)\s*[:.]\s*(.+)', rest)
    if not ch_match:
        return []

    chapter = int(ch_match.group(1))
    verse_part = ch_match.group(2).strip()

    results = []
    for seg in verse_part.split(','):
        seg = seg.strip()
        if not seg:
            continue
        if '-' in seg:
            parts = seg.split('-')
            sm = re.match(r'(\d+)([a-d]*)', parts[0].strip())
            em = re.match(r'(\d+)([a-d]*)', parts[1].strip())
            if sm and em:
                sv, ev = int(sm.group(1)), int(em.group(1))
                sp = sm.group(2) or None
                ep = em.group(2) or None
                results.append((shortname, chapter, sv, sp))
                for v in range(sv + 1, ev):
                    results.append((shortname, chapter, v, None))
                if ev > sv:
                    results.append((shortname, chapter, ev, ep))
        else:
            m = re.match(r'(\d+)([a-d]*)', seg)
            if m:
                results.append((shortname, chapter, int(m.group(1)), m.group(2) or None))
    return results


def clean_verse(text: str) -> str:
    text = re.sub(r'^\d+\.\s*', '', text)
    text = text.strip().strip('"')
    return text


def extract_part(text: str, part: str | None) -> str:
    if not part:
        return text
    parts = re.split(r';', text)
    idx = ord(part[0]) - ord('a')
    if 0 <= idx < len(parts):
        if len(part) > 1:
            end_idx = ord(part[-1]) - ord('a')
            return '; '.join(p.strip() for p in parts[idx:end_idx + 1] if p.strip())
        return parts[idx].strip()
    return text


def resolve_from_bible(ref_str: str, verses: dict) -> str | None:
    parsed = parse_ref(ref_str)
    if not parsed:
        return None
    text_parts = []
    for shortname, chapter, verse, part in parsed:
        raw = verses.get((shortname, chapter, verse))
        if raw is None:
            continue
        cleaned = clean_verse(raw)
        if part:
            cleaned = extract_part(cleaned, part)
        text_parts.append(cleaned)
    if not text_parts:
        return None
    full = ' '.join(text_parts).strip().rstrip(',;')
    if not full.endswith(('.', '!', '?', ':')):
        full += '.'
    return full


def looks_truncated(text: str) -> bool:
    text = text.strip()
    if not text:
        return True
    if len(text) < 25:
        return True
    incomplete = (
        ' while he', ' that i', ' that you', ' and the', ' and he',
        ' and i', ' for the', ' for i', ' for you', ' to the',
        ' to me', ' to you', ' of the', ' in the', ' with the',
        ' so that', ' who has', ' who is', ' but on', ' and are burdened,',
    )
    lower = text.lower()
    if any(lower.endswith(e) for e in incomplete):
        return True
    if not text.endswith(('.', '!', '?', ':', '"')):
        if len(text) < 55:
            return True
    return False


def normalize_ref(ref: str) -> str:
    ref = re.sub(r'^(?:See\s+|Cf\.?\s+)', '', ref.strip(), flags=re.IGNORECASE)
    ref = re.sub(r'(\d+)\.(\d)', r'\1:\2', ref)
    return ref.strip().lower()


def main():
    args = parse_args()
    root = Path(__file__).resolve().parents[1]
    csv_path = root / args.csv
    verses_path = root / args.verses

    print(f'Loading verses from {verses_path.name}...')
    verses = load_verses(verses_path)
    print(f'  {len(verses)} verses loaded')

    with csv_path.open(encoding='utf-8-sig', newline='') as f:
        rows = list(csv.DictReader(f))
        fieldnames = list(rows[0].keys()) if rows else []

    # Build index: lectionary_number -> list of (index, row)
    by_lect_num: dict[str, list[tuple[int, dict]]] = defaultdict(list)
    # Build index: normalized acclamation_ref -> list of (index, row)
    by_ref: dict[str, list[tuple[int, dict]]] = defaultdict(list)

    for idx, row in enumerate(rows):
        ln = row.get('lectionary_number', '').strip()
        if ln:
            by_lect_num[ln].append((idx, row))
        ref = row.get('acclamation_ref', '').strip()
        if ref:
            by_ref[normalize_ref(ref)].append((idx, row))

    # Find all truncated rows
    truncated: list[tuple[int, dict]] = []
    for idx, row in enumerate(rows):
        text = row.get('acclamation_text', '').strip()
        if looks_truncated(text) and row.get('acclamation_ref', '').strip():
            truncated.append((idx, row))

    print(f'\nTotal rows: {len(rows)}')
    print(f'Truncated acclamation rows: {len(truncated)}')

    # Manual overrides for paraphrased acclamations that can't be resolved from Bible
    MANUAL_OVERRIDES: dict[tuple[str, str], str] = {
        ('John 4.42, 15', 'Lord, you are truly the Saviour of the world; give me living water, that I'):
            'Lord, you are truly the Savior of the world; give me living water, that I may never thirst again.',
    }

    patches: list[tuple[int, str, str, str]] = []  # (idx, source, old_text, new_text)

    for idx, row in truncated:
        ref = row.get('acclamation_ref', '').strip()
        old_text = row.get('acclamation_text', '').strip()
        ln = row.get('lectionary_number', '').strip()
        norm_r = normalize_ref(ref)

        # Strategy 1: Find sibling row with same lectionary_number and same ref
        # that has complete text
        sibling_text = None
        if ln:
            for s_idx, s_row in by_lect_num[ln]:
                if s_idx == idx:
                    continue
                s_ref = normalize_ref(s_row.get('acclamation_ref', ''))
                s_text = s_row.get('acclamation_text', '').strip()
                if s_ref == norm_r and s_text and not looks_truncated(s_text):
                    sibling_text = s_text
                    break

        # Strategy 2: Find any row with same normalized ref that has complete text
        if not sibling_text:
            for s_idx, s_row in by_ref.get(norm_r, []):
                if s_idx == idx:
                    continue
                s_text = s_row.get('acclamation_text', '').strip()
                if s_text and not looks_truncated(s_text):
                    sibling_text = s_text
                    break

        if sibling_text:
            patches.append((idx, 'sibling', old_text, sibling_text))
            continue

        # Strategy 2b: Check manual overrides
        override_key = (ref, old_text)
        if override_key in MANUAL_OVERRIDES:
            patches.append((idx, 'manual', old_text, MANUAL_OVERRIDES[override_key]))
            continue

        # Strategy 3: Resolve from Bible
        bible_text = resolve_from_bible(ref, verses)
        if bible_text and len(bible_text) > len(old_text) + 5:
            patches.append((idx, 'bible', old_text, bible_text))
            continue

        # Unresolved
        patches.append((idx, 'UNRESOLVED', old_text, ''))

    resolved = [p for p in patches if p[1] != 'UNRESOLVED']
    unresolved = [p for p in patches if p[1] == 'UNRESOLVED']

    print(f'Resolved: {len(resolved)} ({sum(1 for p in resolved if p[1] == "sibling")} sibling, {sum(1 for p in resolved if p[1] == "bible")} bible)')
    print(f'Unresolved: {len(unresolved)}')

    print('\n--- RESOLVED PATCHES ---')
    for idx, source, old_text, new_text in resolved:
        row = rows[idx]
        print(
            f'\n[{idx + 2}] {row["season"]} | {row["week"]} | {row["day"]} | {row.get("reading_cycle", "")}'
            f'\n  ref: {row["acclamation_ref"]}'
            f'\n  source: {source}'
            f'\n  old: {old_text!r}'
            f'\n  new: {new_text!r}'
        )

    if unresolved:
        print('\n--- UNRESOLVED ---')
        for idx, _, old_text, _ in unresolved:
            row = rows[idx]
            print(
                f'[{idx + 2}] {row["season"]} | {row["week"]} | {row["day"]}'
                f' | ref={row["acclamation_ref"]!r} | text={old_text!r}'
            )

    if not args.write:
        print('\nDry run. Use --write to apply.')
        return 0

    count = 0
    for idx, source, old_text, new_text in resolved:
        rows[idx]['acclamation_text'] = new_text
        count += 1

    with csv_path.open('w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f'\nPatched {count} rows in {csv_path.name}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
