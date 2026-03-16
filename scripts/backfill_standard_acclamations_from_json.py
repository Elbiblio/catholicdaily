#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import json
import re
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path


BOOK_ALIASES = {
    'amos': 'Am',
    'am': 'Am',
    'ezekiel': 'Ez',
    'ez': 'Ez',
    'hosea': 'Hos',
    'hos': 'Hos',
    'isaiah': 'Isa',
    'isa': 'Isa',
    'jeremiah': 'Jer',
    'jer': 'Jer',
    'joel': 'Jl',
    'jl': 'Jl',
    'john': 'John',
    'jn': 'John',
    'jude': 'Jude',
    'luke': 'Luke',
    'lk': 'Luke',
    'mark': 'Mark',
    'mk': 'Mark',
    'matthew': 'Matt',
    'mt': 'Matt',
    'philippians': 'Phil',
    'phil': 'Phil',
    'proverbs': 'Prov',
    'prov': 'Prov',
    'psalm': 'Ps',
    'psalms': 'Ps',
    'ps': 'Ps',
    'romans': 'Rom',
    'rom': 'Rom',
    'timothy': 'Tim',
}


@dataclass(frozen=True)
class Candidate:
    raw: str
    ref: str
    text: str
    score: int


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument('--csv', dest='csv_path', default='standard_lectionary_complete.csv')
    parser.add_argument('--json', dest='json_path', default='assets/data/readings_rows.json')
    parser.add_argument('--write', action='store_true')
    return parser.parse_args()


def normalize_spaces(value: str) -> str:
    return re.sub(r'\s+', ' ', value.replace('\n', ' ').replace('\r', ' ')).strip()


def normalize_reference(value: str) -> str:
    normalized = normalize_spaces(value)
    normalized = re.sub(r'^\(s h o r te r \)\s*', '', normalized, flags=re.IGNORECASE)
    normalized = re.sub(r'^(?:See\s+|Cf\.?\s+)', '', normalized, flags=re.IGNORECASE)
    normalized = normalized.replace('Ma tt', 'Matt')
    normalized = normalized.replace('Lu ke', 'Luke')
    normalized = normalized.replace('Jo hn', 'John')
    normalized = normalized.replace('Ma rk', 'Mark')
    normalized = re.sub(r'(\d+)\.(\d)', r'\1:\2', normalized)
    normalized = normalized.replace(' .', '.').replace(' ,', ',')
    normalized = normalized.strip(' ,')

    match = re.match(r'^((?:[1-3]\s+)?[A-Za-z]+(?:\s+[A-Za-z]+)*)\s+(.+)$', normalized)
    if not match:
        return normalized

    book = match.group(1).strip()
    rest = match.group(2).strip()
    canonical_book = ' '.join(
        BOOK_ALIASES.get(part.lower(), part)
        for part in book.split()
    )
    return f'{canonical_book} {rest}'.strip()


def split_acclamation(value: str) -> tuple[str, str]:
    cleaned = normalize_spaces(value)
    cleaned = re.sub(r'^(?:See\s+|Cf\.?\s+)', '', cleaned, flags=re.IGNORECASE)
    if not cleaned:
        return '', ''

    tokens = cleaned.split()
    reference_tokens: list[str] = []
    verse_token_index = -1

    for index, token in enumerate(tokens):
        stripped = token.strip(';,')
        if verse_token_index >= 0:
            if re.fullmatch(r'[\dA-Za-z:.,;\-–]+', stripped) and re.search(r'\d', stripped):
                reference_tokens.append(stripped)
                continue
            break

        reference_tokens.append(stripped)
        if re.search(r'\d', stripped) and (':' in stripped or '.' in stripped):
            verse_token_index = index

    if verse_token_index < 0 or not reference_tokens:
        return '', cleaned

    reference = normalize_reference(' '.join(reference_tokens))
    text = ' '.join(tokens[len(reference_tokens):]).strip()
    return reference, text or cleaned


def score_candidate(raw: str, ref: str, text: str) -> int:
    score = len(text)
    lower = text.lower()
    if not text:
        score -= 1000
    if any(ch.islower() for ch in text):
        score += 25
    if text.endswith('.'):
        score += 5
    if any(token in lower for token in [' says ', ' lord', ' christ', ' god', ' may ', ' behold', ' whoever ']):
        score += 20
    if raw.lower().startswith('see '):
        score -= 3
    if raw.lower().startswith('cf.') or raw.lower().startswith('cf '):
        score -= 2
    if len(text) < 12:
        score -= 200
    return score


def load_best_candidates(json_path: Path) -> dict[str, Candidate]:
    rows = json.loads(json_path.read_text(encoding='utf-8'))
    grouped: dict[str, list[Candidate]] = defaultdict(list)

    for row in rows:
        if row.get('position') != 4:
            continue
        raw = normalize_spaces(str(row.get('gospel_acclamation') or ''))
        if not raw:
            continue
        gospel = normalize_reference(str(row.get('reading') or ''))
        if not gospel:
            continue
        ref, text = split_acclamation(raw)
        candidate = Candidate(
            raw=raw,
            ref=ref,
            text=text,
            score=score_candidate(raw, ref, text),
        )
        grouped[gospel].append(candidate)

    best: dict[str, Candidate] = {}
    for gospel, candidates in grouped.items():
        unique: dict[tuple[str, str], Candidate] = {}
        for candidate in candidates:
            key = (candidate.ref.lower(), candidate.text.lower())
            previous = unique.get(key)
            if previous is None or candidate.score > previous.score:
                unique[key] = candidate
        best[gospel] = sorted(unique.values(), key=lambda item: item.score, reverse=True)[0]

    return best


def should_replace(current_text: str, candidate_text: str) -> bool:
    current = normalize_spaces(current_text)
    candidate = normalize_spaces(candidate_text)
    if not candidate:
        return False
    if not current:
        return True
    if current.lower() == candidate.lower():
        return False
    if candidate.lower().startswith(current.lower()) and len(candidate) >= len(current) + 8:
        return True
    if len(current) < 55 and len(candidate) >= len(current) + 20:
        return True
    return False


def looks_suspicious(current_text: str) -> bool:
    current = normalize_spaces(current_text)
    if not current:
        return True

    if len(current) < 28:
        return True

    if len(current) < 45 and not current.endswith(('.', '!', '?', ':')):
        return True

    incomplete_endings = (
        ' while he',
        ' that i',
        ' that you',
        ' and the',
        ' and he',
        ' and i',
        ' for the',
        ' for i',
        ' for you',
        ' to the',
        ' to me',
        ' to you',
        ' of the',
        ' in the',
        ' with the',
    )
    lower = current.lower()
    if any(lower.endswith(ending) for ending in incomplete_endings):
        return True

    return False


def main() -> int:
    args = parse_args()
    root = Path(__file__).resolve().parents[1]
    csv_path = (root / args.csv_path).resolve()
    json_path = (root / args.json_path).resolve()

    best_candidates = load_best_candidates(json_path)

    with csv_path.open(encoding='utf-8-sig', newline='') as handle:
        rows = list(csv.DictReader(handle))
        fieldnames = list(rows[0].keys()) if rows else []

    replacements: list[tuple[int, dict[str, str], Candidate]] = []
    for index, row in enumerate(rows):
        gospel = normalize_reference(row.get('gospel', ''))
        candidate = best_candidates.get(gospel)
        if candidate is None:
            continue

        current_ref = normalize_reference(row.get('acclamation_ref', ''))
        if current_ref and candidate.ref and current_ref.lower() != candidate.ref.lower():
            continue
        current_text = row.get('acclamation_text', '')
        if not (should_replace(current_text, candidate.text) or (looks_suspicious(current_text) and len(candidate.text) > len(normalize_spaces(current_text)) + 8)):
            continue
        replacements.append((index, row, candidate))

    print(f'CSV rows: {len(rows)}')
    print(f'Legacy gospel acclamations: {len(best_candidates)}')
    print(f'Replacements identified: {len(replacements)}')

    for index, row, candidate in replacements:
        print(
            f"[{index + 2}] {row.get('season', '')} | {row.get('week', '')} | {row.get('day', '')} | "
            f"{row.get('reading_cycle', '')} | {row.get('gospel', '')}\n"
            f"  old_ref={row.get('acclamation_ref', '')}\n"
            f"  old_text={row.get('acclamation_text', '')}\n"
            f"  new_ref={candidate.ref or row.get('acclamation_ref', '')}\n"
            f"  new_text={candidate.text}\n"
        )

    if not args.write:
        return 0

    for index, row, candidate in replacements:
        if candidate.ref and not normalize_reference(row.get('acclamation_ref', '')):
            row['acclamation_ref'] = candidate.ref
        row['acclamation_text'] = candidate.text
        rows[index] = row

    with csv_path.open('w', encoding='utf-8', newline='') as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f'Updated {len(replacements)} rows in {csv_path.name}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
