#!/usr/bin/env python3
from datetime import date, timedelta

def easter(year):
    a = year % 19
    b = year // 100
    c = year % 100
    d = b // 4
    e = b % 4
    f = (b + 8) // 25
    g = (b - f + 1) // 3
    h = (19 * a + b - d - g + 15) % 30
    i = c // 4
    k = c % 4
    l = (32 + 2 * e + 2 * i - h - k) % 7
    m = (a + 11 * h + 22 * l) // 451
    month = (h + l - 7 * m + 114) // 31
    day = ((h + l - 7 * m + 114) % 31) + 1
    return date(year, month, day)

def advent_start(year):
    christmas = date(year, 12, 25)
    days_to_prev_sunday = (christmas.weekday() + 1) % 7  # weekday(): Mon=0
    # 4th Sunday before Christmas
    return christmas - timedelta(days=days_to_prev_sunday + 21)

e2026 = easter(2026)
adv2026 = advent_start(2026)

print(f"Easter 2026: {e2026} ({e2026.strftime('%A')})")
print(f"Ash Wednesday 2026: {e2026 - timedelta(days=46)}")
print(f"Palm Sunday 2026: {e2026 - timedelta(days=7)}")
print(f"Pentecost 2026: {e2026 + timedelta(days=49)} ({(e2026 + timedelta(days=49)).strftime('%A')})")
print(f"Trinity Sunday 2026: {e2026 + timedelta(days=56)}")
print(f"Corpus Christi 2026: {e2026 + timedelta(days=63)}")
print(f"Sacred Heart 2026: {e2026 + timedelta(days=68)}")
print(f"Advent start 2026: {adv2026} ({adv2026.strftime('%A')})")

# Christ the King = last Sunday before Advent
ck = adv2026 - timedelta(days=1)
while ck.weekday() != 6:  # Sunday = 6
    ck -= timedelta(days=1)
print(f"Christ the King 2026: {ck} ({ck.strftime('%A')})")

# Nov 22 weekday
d = date(2026, 11, 22)
print(f"Nov 22 2026: {d.strftime('%A')}")

# Nov 30 2025 weekday
d2 = date(2025, 11, 30)
print(f"Nov 30 2025: {d2.strftime('%A')}")

# Easter Octave Wednesday
eo_wed = e2026 + timedelta(days=3)
print(f"Easter Octave Wed: {eo_wed} ({eo_wed.strftime('%A')})")

# Dec 8 2025 weekday
d3 = date(2025, 12, 8)
print(f"Dec 8 2025: {d3.strftime('%A')}")

# Holy Family 2026
for day in range(26, 32):
    d = date(2026, 12, day)
    if d.weekday() == 6:
        print(f"Holy Family 2026: {d} (Sunday)")
        break
else:
    print("Holy Family 2026: Dec 30 (no Sunday in octave)")
