#!/usr/bin/env python3
"""Analyze Prayer of the Faithful CSV extraction completeness"""

import csv
from pathlib import Path
from collections import Counter

csv_path = Path(r'c:\dev\catholicdaily-flutter\scripts\prayer_of_faithful_1967.csv')

with open(csv_path, 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    rows = list(reader)

print(f'Total entries: {len(rows)}')
print()

occasions = [row['occasion'] for row in rows]
unique_occasions = sorted(set(occasions))

print(f'Unique occasions ({len(unique_occasions)}):')
for occ in unique_occasions:
    count = occasions.count(occ)
    print(f'  {occ}: {count} occurrence(s)')

print()
print('All entries:')
for i, row in enumerate(rows, 1):
    print(f'{i}. {row["occasion"]} (page {row["page_number"]})')
