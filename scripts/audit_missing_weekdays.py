import csv
from collections import defaultdict

path = r'c:\dev\catholicdaily-flutter\standard_lectionary_complete.csv'

with open(path, newline='', encoding='utf-8') as f:
    rows = list(csv.DictReader(f))

missing = [
    r for r in rows
    if r['day'] != 'Sunday' and not r['first_reading']
]

by_season = defaultdict(list)
for row in missing:
    by_season[row['season']].append(row)

for season, items in by_season.items():
    print(f'\n## {season} ({len(items)})')
    for row in items[:80]:
        print(
            row['week'], '|', row['day'], '|', row['weekday_cycle'], '|',
            row['reading_cycle'], '|', row['lectionary_number'], '|', row['psalm_reference']
        )
