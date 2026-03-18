from pathlib import Path

from standard_lectionary_builder import build_rows, extract_weekday_refs

refs = extract_weekday_refs(Path(r'c:\dev\catholicdaily-flutter\scripts\weekday_a_full.txt'))
for key, value in refs.items():
    if key[0] == 'Advent' and key[1] == '1' and key[2] == 'Monday':
        print('REF', key, value)

rows = build_rows()
for row in rows:
    if row['season'] == 'Advent' and row['week'] == '1' and row['day'] == 'Monday':
        print('ROW', row['weekday_cycle'], row['reading_cycle'], row['first_reading'], row['gospel'])
