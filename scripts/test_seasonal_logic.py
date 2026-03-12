#!/usr/bin/env python3
"""Test seasonal logic for gospel acclamations."""

import datetime as dt


def calculate_easter(year: int) -> dt.date:
    """Calculate Easter Sunday using Anonymous Gregorian algorithm."""
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
    
    return dt.date(year, month, day)


def is_during_lent(date: dt.date) -> bool:
    """Check if date is during Lent (Ash Wednesday to Holy Saturday)."""
    year = date.year
    
    # Calculate Easter Sunday for the given year
    easter = calculate_easter(year)
    
    # Ash Wednesday is 46 days before Easter Sunday
    ash_wednesday = easter - dt.timedelta(days=46)
    
    # Holy Saturday is the day before Easter Sunday
    holy_saturday = easter - dt.timedelta(days=1)
    
    # Check if date is within Lent period
    return (ash_wednesday <= date <= holy_saturday)


def is_sunday(date: dt.date) -> bool:
    """Check if date is a Sunday."""
    return date.weekday() == 6  # Monday=0, Sunday=6


def get_seasonal_acclamation(date: dt.date) -> str:
    """Get seasonal gospel acclamation for a given date."""
    # Check if date is during Lent (excluding Sundays)
    if is_during_lent(date) and not is_sunday(date):
        return "Glory and praise to you, Lord Jesus Christ."
    
    # Outside Lent, use Alleluia
    return "Alleluia."


def main():
    print("Gospel Acclamation Seasonal Logic Test")
    print("=" * 50)
    
    test_years = [2024, 2025, 2026, 2027]
    
    for year in test_years:
        print(f"\n{year} Liturgical Calendar:")
        print("-" * 30)
        
        easter = calculate_easter(year)
        ash_wednesday = easter - dt.timedelta(days=46)
        holy_saturday = easter - dt.timedelta(days=1)
        
        print(f"Easter Sunday: {easter} ({easter.strftime('%A')})")
        print(f"Ash Wednesday: {ash_wednesday} ({ash_wednesday.strftime('%A')})")
        print(f"Holy Saturday: {holy_saturday} ({holy_saturday.strftime('%A')})")
        
        # Test key dates
        test_dates = [
            (ash_wednesday, "Ash Wednesday"),
            (dt.date(year, 3, 15), "Mid-Lent Weekday"),
            (dt.date(year, 3, 1), "Pre-Lent"),
            (easter, "Easter Sunday"),
            (easter + dt.timedelta(days=1), "Easter Monday"),
        ]
        
        print("\nTest Dates:")
        for date, description in test_dates:
            acclamation = get_seasonal_acclamation(date)
            is_lent = is_during_lent(date)
            is_sun = is_sunday(date)
            
            print(f"  {date} ({description}): {acclamation}")
            print(f"    Lent: {is_lent}, Sunday: {is_sun}")
    
    # Test specific 2026 dates
    print(f"\n2026 Specific Test Dates:")
    print("-" * 30)
    
    dates_2026 = [
        (dt.date(2026, 3, 3), "Ash Wednesday"),
        (dt.date(2026, 3, 8), "First Sunday of Lent"),
        (dt.date(2026, 3, 10), "Tuesday in Lent"),
        (dt.date(2026, 4, 2), "Holy Thursday"),
        (dt.date(2026, 4, 3), "Good Friday"),
        (dt.date(2026, 4, 4), "Holy Saturday"),
        (dt.date(2026, 4, 5), "Easter Sunday"),
        (dt.date(2026, 4, 6), "Easter Monday"),
        (dt.date(2026, 3, 9), "Today (outside Lent)"),
    ]
    
    for date, description in dates_2026:
        acclamation = get_seasonal_acclamation(date)
        print(f"  {date} ({description}): {acclamation}")


if __name__ == "__main__":
    main()
