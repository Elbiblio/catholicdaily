"""Restore the 23 omitted responsorial entries from the bundled source texts.

Only empty fields are filled; existing curated readings are preserved. Source
page keys identify the catalog rows; line numbers identify the original canticle
and its response. Run from the repository root with python -m scripts.restore_lectionary_canticles.
"""
import csv
import io
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SOURCE_LINES = {
    'weekday_a_full.txt': {59: 2363, 147: 5859, 238: 9620, 478: 19415},
    'weekday_b_full.txt': {
        63: 2573, 106: 4261, 158: 6322, 165: 6625, 209: 8390,
        295: 11876, 301: 12106, 317: 12776, 345: 13837, 408: 16403,
        413: 16633, 415: 16744, 418: 16870, 421: 17008, 425: 17140, 427: 17248,
    },
}
# Cross-checked against sunday_readings_columns.txt and lectionary_psalms.csv.
SUNDAYS = {
    137: ('Ps 19:8, 9, 10, 15', 'Your words are spirit, Lord, and they are life.'),
    156: ('Ps 50:1, 8, 12-13, 14-15', 'To the upright I will show the saving power of God.'),
    173: ('Ps 69:14, 17, 30-31, 33-34, 36-37', 'Seek the Lord, you who are poor, and your hearts will revive.'),
}


def restore():
    path = ROOT / 'standard_lectionary_complete.csv'
    lines = path.read_text(encoding='utf-8-sig').splitlines(keepends=True)
    header = next(csv.reader([lines[0]]))
    count = 0
    for index, line in enumerate(lines[1:], 1):
        row = dict(zip(header, next(csv.reader([line]))))
        # Normalize date keys even when the psalm is filled in this same run.
        original = dict(row)
        if row['season'] == 'Lent' and row['lectionary_number'] in {'220', '221', '222'}:
            row['week'] = 'After Ash Wed'
            row['psalm_response'] = row['psalm_response'].rstrip('+')
        elif row['season'] == 'Advent' and re.fullmatch(r'December (?:1[7-9]|2[0-4])', row['day']):
            row['week'] = 'Dec 17-24'
        if row['psalm_reference'].strip():
            if original == row:
                continue
            output = io.StringIO(newline='')
            csv.writer(output, lineterminator='\n').writerow([row[field] for field in header])
            lines[index] = output.getvalue()
            continue
        source, page = row['source_file'], int(row['source_page'])
        if source == 'sunday_readings_columns.txt':
            reference, response = SUNDAYS[page]
        else:
            source_line = SOURCE_LINES[source][page]
            excerpt = (ROOT / 'scripts' / source).read_text(encoding='utf-8').splitlines()[source_line - 1:source_line + 4]
            assert excerpt[0].startswith('RESPONSORIAL CANTICLE '), (source, source_line)
            reference = re.sub(r'\s*\(R\..*', '', excerpt[0].removeprefix('RESPONSORIAL CANTICLE '))
            assert excerpt[1].startswith('R. ')
            response = excerpt[1].removeprefix('R. ')
            if excerpt[2] and not excerpt[2][0].isdigit():
                response += ' ' + excerpt[2]
            response = response.replace('My hearts rejoices', 'My heart rejoices')
        row['psalm_reference'], row['psalm_response'] = reference.strip(), response.strip()
        output = io.StringIO(newline='')
        csv.writer(output, lineterminator='\n').writerow([row[field] for field in header])
        lines[index] = output.getvalue()
        count += 1
    path.write_text(''.join(lines), encoding='utf-8', newline='')
    return count


if __name__ == '__main__':
    print(f'Restored {restore()} responsorial entries.')
