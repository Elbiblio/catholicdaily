import csv
from collections import Counter

path = r'c:\dev\catholicdaily-flutter\standard_lectionary_complete.csv'

with open(path, newline='', encoding='utf-8') as f:
    rows = list(csv.DictReader(f))

missing_sundays = [r for r in rows if r['day'] == 'Sunday' and r['sunday_cycle'] and not r['first_reading']]
print('Missing Sunday refs:', len(missing_sundays))
for r in missing_sundays[:80]:
    print(r['season'], r['week'], r['sunday_cycle'], '|', r['psalm_reference'])

print('\nMissing weekday Dec 24 rows:')
for r in rows:
    if r['day'] == 'December 24':
        print(r)

print('\nMissing weekday first reading by season:')
counter = Counter(r['season'] for r in rows if r['day'] != 'Sunday' and not r['first_reading'])
for k, v in counter.items():
    print(k, v)
