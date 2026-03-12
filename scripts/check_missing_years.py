#!/usr/bin/env python3
import sqlite3
import datetime as dt
from pathlib import Path

db_path = Path("assets/readings.db")
conn = sqlite3.connect(str(db_path))
cursor = conn.cursor()

# Get year breakdown
cursor.execute("""
    SELECT 
        strftime('%Y', datetime(timestamp, 'unixepoch')) as year,
        COUNT(*) as missing
    FROM readings 
    WHERE position = 2 
      AND (psalm_response IS NULL OR TRIM(psalm_response) = '')
    GROUP BY year 
    ORDER BY year
""")

print("Missing psalms by year:")
print("-" * 40)
total = 0
for row in cursor.fetchall():
    year, count = row
    print(f"{year}: {count:4d} missing")
    total += count

print("-" * 40)
print(f"Total: {total:4d} missing")

conn.close()
