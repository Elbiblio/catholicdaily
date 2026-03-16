import sqlite3
from datetime import datetime, timezone

DB = r'c:\dev\catholicdaily-flutter\assets\readings.db'
DATES = [
    '2024-02-14',
    '2024-02-17',
    '2024-02-24',
    '2024-03-24',
    '2024-03-28',
    '2024-03-29',
    '2024-04-13',
    '2024-04-20',
    '2024-04-27',
    '2024-05-04',
    '2024-05-11',
    '2024-12-20',
    '2025-03-01',
]

conn = sqlite3.connect(DB)
conn.row_factory = sqlite3.Row

for date_text in DATES:
    year, month, day = map(int, date_text.split('-'))
    ts = int(datetime(year, month, day, 8, 0, 0, tzinfo=timezone.utc).timestamp())
    rows = conn.execute(
        'SELECT position, reading, psalm_response, gospel_acclamation FROM readings WHERE timestamp = ? ORDER BY position',
        (ts,),
    ).fetchall()
    print('===', date_text, ts, '===')
    for row in rows:
        print(row['position'], '|', row['reading'], '|', row['psalm_response'], '|', row['gospel_acclamation'])
    print()

conn.close()
