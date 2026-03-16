import csv

CSV_PATH = r'c:\dev\catholicdaily-flutter\standard_lectionary_complete.csv'

with open(CSV_PATH, newline='', encoding='utf-8') as f:
    rows = list(csv.DictReader(f))

missing = [row for row in rows if not (row.get('gospel') or '').strip()]
print(f'Missing gospel rows: {len(missing)}')
for row in missing:
    print({
        'season': row['season'],
        'week': row['week'],
        'day': row['day'],
        'weekday_cycle': row['weekday_cycle'],
        'sunday_cycle': row['sunday_cycle'],
        'reading_cycle': row['reading_cycle'],
        'lectionary_number': row['lectionary_number'],
        'first_reading': row['first_reading'],
        'psalm_reference': row['psalm_reference'],
    })
