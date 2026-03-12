#!/usr/bin/env python3
"""Test script for tiered psalm resolver."""
from __future__ import annotations

import datetime as dt
import sqlite3
import sys
from pathlib import Path

from psalm_source_resolver import (
    TieredPsalmResolver,
    sunday_cycle_for_date,
    weekday_cycle_for_date,
)


def main() -> int:
    db_path = Path("assets/readings.db").resolve()
    if not db_path.exists():
        print(f"DB not found: {db_path}", file=sys.stderr)
        return 1

    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row
    resolver = TieredPsalmResolver(conn)

    # Test dates with known missing psalms
    test_dates = [
        dt.date(2020, 3, 15),  # Early pandemic date
        dt.date(2021, 7, 4),   # Mid-year date
        dt.date(2022, 12, 25), # Christmas
        dt.date(2023, 4, 9),   # Easter Sunday
        dt.date(2024, 1, 1),   # New Year
        dt.date(2025, 6, 15),  # Mid-year
        dt.date(2026, 3, 1),   # Recent date
    ]

    print("Testing Tiered Psalm Resolver\n" + "=" * 70)

    for test_date in test_dates:
        # Get psalm reference from database
        ts = int(dt.datetime.combine(test_date, dt.time(0, 0), tzinfo=dt.UTC).timestamp())
        row = conn.execute(
            """
            SELECT reading, psalm_response
            FROM readings
            WHERE position = 2
              AND timestamp >= ?
              AND timestamp < ?
            LIMIT 1
            """,
            (ts, ts + 86400),
        ).fetchone()

        if not row:
            print(f"\n{test_date}: No psalm reading found in database")
            continue

        psalm_ref = str(row["reading"]).strip()
        existing = str(row["psalm_response"] or "").strip()
        
        print(f"\n{test_date} | {psalm_ref[:50]}")
        print(f"  Existing response: {existing[:60] if existing else '(none)'}")

        year = test_date.year
        sunday_cycle = sunday_cycle_for_date(test_date)
        weekday_cycle = weekday_cycle_for_date(test_date)

        result, report = resolver.resolve_with_report(
            test_date, psalm_ref, year, sunday_cycle, weekday_cycle
        )

        if result:
            print(f"  ✓ Resolved via: {result.source} (confidence: {result.confidence})")
            print(f"  Response: {result.response[:80]}")
            print(f"  Source URL: {result.source_url}")
        else:
            print(f"  ✗ UNRESOLVED")

        print(f"  Sources tried: {report}")

    conn.close()
    print("\n" + "=" * 70)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
