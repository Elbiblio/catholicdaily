"""Fill Bible pack gaps from calendar output, without inventing lectionary text.

Export references with calendar_psalm_coverage_test.dart and
--dart-define=PSALM_COVERAGE_OUTPUT=verification/calendar-psalm-references.json,
then run python -m scripts.complete_calendar_psalm_packs --references <file>.
Existing reviewed rows are retained. New rows use bundled Bible text and provenance.
"""
from __future__ import annotations

import argparse
import csv
import json
from dataclasses import replace
from pathlib import Path

from scripts.psalm_sources.bible_databases import extract_bible_selections, parse_selection
from scripts.psalm_sources.source_packs import PACK_FIELDS, RuntimePsalmPackRow, pack_rows_from_editions

ROOT = Path(__file__).resolve().parents[1]
PACKS = ROOT / 'assets/data/psalm_editions'
TOBIT_SELECTIONS = {
    'tob13:2,6a,6b,6c,6d': 'Tobit 13:2,6',
    'tob13:2,3-4,6abcd,6ef': 'Tobit 13:2,3-4,6',
}
# Checked against the bundled lectionary text and RSVCE: the NABRE import
# retains only parts of some verse rows. Do not certify these as complete.
INCOMPLETE_NABRE = set(TOBIT_SELECTIONS) | {
    'ps13:6ab,6c',
    '1chr29:10b,11abc,11d-12a,12bcd',
    'ex15:1-2,3-4,5-6',
    'ex15:1-2,3-4,5-6,17-18',
    'deut32:3-4a,7,8,9+12',
    'isa12:1-6',
    '1sam2:1,4-5,6-7,8abcd',
}


def load_rows(filename: str) -> list[RuntimePsalmPackRow]:
    with (PACKS / filename).open(encoding='utf-8-sig', newline='') as handle:
        return [RuntimePsalmPackRow(**{
            key: int(value) if key == 'display_priority' else value
            for key, value in row.items()
            if key not in {'raw_sha256', 'normalized_sha256'}
        }) for row in csv.DictReader(handle)]


def generate(references: dict[str, str]) -> dict[str, object]:
    output = {}
    report = {}
    for edition, filename, database in [
        ('local_rsvce', 'rsvce.csv', 'rsvce.db'),
        ('local_nabre', 'nabre.csv', 'nabre.db'),
    ]:
        rows = load_rows(filename)
        # The imported NABRE rows omit much of these selections. Use the
        # verified RSVCE fallback instead of presenting incomplete NABRE text.
        if edition == 'local_nabre':
            rows = [row for row in rows if row.reference_normalized not in INCOMPLETE_NABRE]
        # Re-extract only selections affected by corrected canticle numbering.
        for index, row in enumerate(rows):
            parsed = parse_selection(row.reference_normalized)
            affected = (
                edition == 'local_rsvce' and parsed.book == 'dan' and parsed.chapter == 3
                and any(any(52 <= verse <= 56 for verse in group.verses) for group in parsed.groups)
            ) or (edition == 'local_nabre' and parsed.book == 'jonah' and parsed.chapter == 2) or row.reference_normalized in TOBIT_SELECTIONS
            if affected:
                text = extract_bible_selections(
                    ROOT / 'assets' / database, edition_id=edition,
                    selections=[(TOBIT_SELECTIONS.get(row.reference_normalized, row.reference_normalized), row.response_text)],
                )[0]
                rows[index] = replace(row, stanzas_text=text.stanzas_text)
        existing = {parse_selection(row.reference_normalized).normalized for row in rows}
        added, unavailable = [], {}
        for reference, response in sorted(references.items()):
            parsed = parse_selection(reference)
            normalized = parsed.normalized
            if normalized in existing:
                continue
            if normalized in INCOMPLETE_NABRE and edition == 'local_nabre':
                unavailable[normalized] = 'Bundled NABRE omits required clauses; use RSVCE fallback.'
                continue
            # September 8's lectionary 6ab/6c corresponds to RSVCE 5/6.
            extraction_reference = 'Ps 13:5,6' if normalized == 'ps13:6ab,6c' else reference
            # A whole-verse Bible fallback includes split verse 6 once.
            extraction_reference = TOBIT_SELECTIONS.get(normalized, extraction_reference)
            try:
                text = extract_bible_selections(
                    ROOT / 'assets' / database,
                    edition_id=edition,
                    selections=[(extraction_reference, response)],
                    source_url=f'repo://assets/{database}',
                )[0]
                text = replace(text, source_edition='RSVCE' if edition == 'local_rsvce' else 'NABRE')
                row = pack_rows_from_editions([text])[edition][0]
                row = replace(row, reference_normalized=normalized,
                              selection_id='calendar:' + normalized, territory='WORLD')
                rows.append(row)
                existing.add(normalized)
                added.append(normalized)
            except LookupError as error:
                unavailable[normalized] = str(error)
        output[filename] = rows
        report[edition] = {'added': added, 'unavailable': unavailable, 'count': len(rows)}

    # Reuse the reviewed Nigerian Nativity text, with its original source URL.
    rows = load_rows('nigeria_365.csv')
    if not any(row.reference_normalized == 'ps13:6ab,6c' for row in rows):
        original = next(row for row in rows if row.reference_normalized == 'ps13:5,6')
        rows.append(replace(original, selection_id=original.selection_id + ':nativity-alias',
                            reference_normalized='ps13:6ab,6c', date_rule='', reading_set_kind='generic'))
    # An alias supports text lookup; it is not another appointed reading for
    # the source date. Keep its original provenance without a calendar date.
    rows = [replace(row, date_rule='', reading_set_kind='generic')
            if row.selection_id.endswith(':nativity-alias') else row for row in rows]
    output['nigeria_365.csv'] = rows

    manifest = json.loads((PACKS / 'manifest.json').read_text(encoding='utf-8'))
    for filename, rows in output.items():
        with (PACKS / filename).open('w', encoding='utf-8', newline='') as handle:
            writer = csv.DictWriter(handle, fieldnames=PACK_FIELDS)
            writer.writeheader()
            writer.writerows(row.to_dict() for row in rows)
        for edition in manifest['editions']:
            if edition['packAsset'].endswith('/' + filename):
                edition['selectionCount'] = len(rows)
    (PACKS / 'manifest.json').write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--references', type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(generate(json.loads(args.references.read_text(encoding='utf-8'))), indent=2))
