import sqlite3
from datetime import datetime, timezone

DB = r'c:\dev\catholicdaily-flutter\assets\readings.db'
DATES = [
    '2024-03-02',
    '2024-03-09',
    '2024-03-16',
    '2024-04-13',
    '2024-04-20',
    '2024-04-27',
    '2024-05-04',
    '2024-05-11',
]

conn = sqlite3.connect(DB)
conn.row_factory = sqlite3.Row
for date_text in DATES:
    year, month, day = map(int, date_text.split('-'))
    ts = int(datetime(year, month, day, 8, 0, 0, tzinfo=timezone.utc).timestamp())
    rows = conn.execute(
        'SELECT position, reading FROM readings WHERE timestamp = ? ORDER BY position',
        (ts,),
    ).fetchall()
    print('===', date_text, '===')
    for row in rows:
        print(row['position'], '|', row['reading'])
    print()
conn.close()
