#!/usr/bin/env python3
"""Debug script to test resolver on actual missing psalms."""
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
    
    # Get some actual missing psalms
    rows = conn.execute("""
        SELECT timestamp, reading
        FROM readings
        WHERE position = 2
          AND (psalm_response IS NULL OR TRIM(psalm_response) = '')
          AND timestamp >= ?
          AND timestamp < ?
        ORDER BY timestamp
        LIMIT 5
    """, (
        int(dt.datetime(2000, 1, 1, tzinfo=dt.UTC).timestamp()),
        int(dt.datetime(2001, 1, 1, tzinfo=dt.UTC).timestamp()),
    )).fetchall()

    print("Testing resolver on actual missing psalms from 2000\n" + "=" * 70)

    resolver = TieredPsalmResolver(conn)

    for row in rows:
        ts = int(row["timestamp"])
        psalm_ref = str(row["reading"]).strip()
        date = dt.datetime.fromtimestamp(ts, tz=dt.UTC).date()
        
        year = date.year
        sunday_cycle = sunday_cycle_for_date(date)
        weekday_cycle = weekday_cycle_for_date(date)

        print(f"\n{date} | {psalm_ref}")
        print(f"  Year: {year}, Sunday: {sunday_cycle}, Weekday: {weekday_cycle}")

        result, report = resolver.resolve_with_report(
            date, psalm_ref, year, sunday_cycle, weekday_cycle
        )

        if result:
            print(f"  ✓ Resolved via: {result.source}")
            print(f"  Response: {result.response[:80]}")
        else:
            print(f"  ✗ UNRESOLVED")
            print(f"  Report: {report}")

    conn.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
