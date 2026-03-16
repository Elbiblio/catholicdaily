#!/usr/bin/env python3
"""Debug why Christ the King title doesn't resolve for Nov 22 2026."""
from datetime import date, timedelta

def advent_start(year):
    christmas = date(year, 12, 25)
    # In Dart: (christmas.weekday + 6) % 7  where weekday: Mon=1..Sun=7
    # christmas 2026 = Friday = weekday 5
    days_to_prev_sunday = (christmas.isoweekday() + 6) % 7  # isoweekday: Mon=1..Sun=7
    return christmas - timedelta(days=days_to_prev_sunday + 21)

def last_sunday_before(day):
    wd = day.isoweekday()  # Mon=1..Sun=7
    # Dart: day.weekday % 7 == 0 ? 7 : day.weekday
    # day.weekday in Dart = isoweekday in Python
    delta = 7 if wd % 7 == 0 else wd
    return day - timedelta(days=delta)

adv = advent_start(2026)
ck = last_sunday_before(adv)
print(f"Advent 2026 start: {adv} ({adv.strftime('%A')}) weekday={adv.isoweekday()}")
print(f"Christ the King: {ck} ({ck.strftime('%A')})")

# Dart _calculateAdventStart:
# final daysToPreviousSunday = (christmas.weekday + 6) % 7;
# return christmas.subtract(Duration(days: daysToPreviousSunday + 21));
# christmas 2026: Dec 25 = Friday = weekday 5
# daysToPreviousSunday = (5 + 6) % 7 = 11 % 7 = 4
# subtract 4 + 21 = 25 days from Dec 25 = Nov 30
print()
print("Simulating Dart _calculateAdventStart for 2026:")
christmas_weekday = 5  # Friday
daysToPreviousSunday = (christmas_weekday + 6) % 7
print(f"  christmas weekday: {christmas_weekday}")
print(f"  daysToPreviousSunday: {daysToPreviousSunday}")
dart_advent = date(2026, 12, 25) - timedelta(days=daysToPreviousSunday + 21)
print(f"  Advent start: {dart_advent} ({dart_advent.strftime('%A')})")

dart_ck = last_sunday_before(dart_advent)
print(f"  Christ the King: {dart_ck} ({dart_ck.strftime('%A')})")

# Check: is the Dart adventStart correct?
# Advent 2026 should start Nov 29 (4th Sunday before Christmas)
# Christmas is Dec 25 (Fri)
# Dec 20 = Sunday, Dec 13 = Sunday, Dec 6 = Sunday, Nov 29 = Sunday
# So Advent starts Nov 29 ✓
# But Dart calculates daysToPreviousSunday=4, 25-4-21=0, Dec 25 - 25 = Nov 30!
print()
print(f"BUG: Dart calculates Advent start as Nov 30, but correct is Nov 29!")
