"""Verify the quality of lectionary_psalms.csv and discrepancies.csv"""
import csv
from collections import Counter

import os
base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rows = list(csv.DictReader(open(os.path.join(base, 'lectionary_psalms.csv'), 'r', encoding='utf-8')))
disc = list(csv.DictReader(open(os.path.join(base, 'discrepancies.csv'), 'r', encoding='utf-8')))

# Spot check: Advent weekdays
adv = [r for r in rows if r['Season'] == 'Advent' and r['Day'] != 'Sunday']
print('=== Advent Weekday sample (first 8) ===')
for r in adv[:8]:
    c = r['Weekday Cycle'] or r['Sunday Cycle']
    print(f"  W{r['Week']} {r['Day']:12s} C:{c:4s} | {r['Full Reference'][:55]:55s} | R. {r['Refrain Text'][:50]}")

# OT Week 1
print('\n=== OT Week 1 entries ===')
ot1 = [r for r in rows if r['Season'] == 'Ordinary Time' and r['Week'] == '1']
for r in ot1:
    c = r['Weekday Cycle'] or r['Sunday Cycle']
    print(f"  {r['Day']:12s} C:{c:4s} | {r['Full Reference'][:50]:50s} | R. {r['Refrain Text'][:45]}")

# OT Week 5
print('\n=== OT Week 5 entries ===')
ot5 = [r for r in rows if r['Season'] == 'Ordinary Time' and r['Week'] == '5']
for r in ot5:
    c = r['Weekday Cycle'] or r['Sunday Cycle']
    print(f"  {r['Day']:12s} C:{c:4s} | {r['Full Reference'][:50]:50s} | R. {r['Refrain Text'][:45]}")

# Lent weekdays
print('\n=== Lent entries (first 10) ===')
lent = [r for r in rows if r['Season'] == 'Lent']
for r in lent[:10]:
    c = r['Weekday Cycle'] or r['Sunday Cycle']
    print(f"  W{r['Week']} {r['Day']:15s} C:{c:4s} | {r['Full Reference'][:50]:50s} | R. {r['Refrain Text'][:45]}")

# Easter
print('\n=== Easter entries (first 10) ===')
easter = [r for r in rows if r['Season'] == 'Easter']
for r in easter[:10]:
    c = r['Weekday Cycle'] or r['Sunday Cycle']
    print(f"  W{r['Week']} {r['Day']:12s} C:{c:4s} | {r['Full Reference'][:50]:50s} | R. {r['Refrain Text'][:45]}")

# Discrepancy analysis
print('\n=== Discrepancy issue counts ===')
issue_types = Counter()
for d in disc:
    for iss in d['Issues'].split('; '):
        issue_types[iss] += 1
for k, v in issue_types.most_common():
    print(f"  {k}: {v}")

print(f'\n=== Discrepancy samples (first 8) ===')
for d in disc[:8]:
    print(f"  {d['Season']:15s} W{d['Week']:8s} {d['Day']:15s} | {d['Issues']}")

# Count entries per season/type
print('\n=== Coverage by Season ===')
for season in ['Advent', 'Christmas', 'Ordinary Time', 'Lent', 'Holy Week', 'Easter']:
    s_rows = [r for r in rows if r['Season'] == season]
    sundays = [r for r in s_rows if r['Day'] == 'Sunday']
    weekdays = [r for r in s_rows if r['Day'] != 'Sunday']
    y1 = [r for r in weekdays if r['Weekday Cycle'] == 'I']
    y2 = [r for r in weekdays if r['Weekday Cycle'] == 'II']
    shared = [r for r in weekdays if r['Weekday Cycle'] == 'I/II']
    print(f"  {season:15s}: {len(s_rows):4d} total | {len(sundays):3d} Sun | {len(shared):3d} shared WD | {len(y1):3d} Y-I | {len(y2):3d} Y-II")
