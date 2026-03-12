#!/usr/bin/env python3
"""Generate comprehensive psalm backfill report."""
from __future__ import annotations

import datetime as dt
import json
import sqlite3
from pathlib import Path


def main() -> int:
    db_path = Path("assets/readings.db")
    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row

    # Overall statistics
    total_psalms = conn.execute(
        "SELECT COUNT(*) FROM readings WHERE position = 2"
    ).fetchone()[0]
    
    filled_psalms = conn.execute(
        """
        SELECT COUNT(*) FROM readings 
        WHERE position = 2 
          AND psalm_response IS NOT NULL 
          AND TRIM(psalm_response) <> ''
        """
    ).fetchone()[0]
    
    missing_psalms = total_psalms - filled_psalms

    # Source breakdown
    source_stats = {}
    for row in conn.execute("""
        SELECT 
            CASE 
                WHEN source_url LIKE 'https://bible.usccb.org%' THEN 'usccb'
                WHEN source_url LIKE 'https://www.catholicgallery.org%' THEN 'catholicgallery'
                WHEN source_url LIKE 'cycle://%' THEN 'cycle_match'
                WHEN source_url LIKE 'cache://%' THEN 'cache'
                ELSE 'other'
            END as source_type,
            COUNT(*) as count
        FROM psalm_responses
        GROUP BY source_type
    """).fetchall():
        source_stats[row["source_type"]] = row["count"]

    # Year breakdown
    year_stats = []
    for row in conn.execute("""
        SELECT 
            strftime('%Y', datetime(timestamp, 'unixepoch')) as year,
            COUNT(*) as total,
            SUM(CASE WHEN psalm_response IS NOT NULL AND TRIM(psalm_response) <> '' 
                THEN 1 ELSE 0 END) as filled,
            SUM(CASE WHEN psalm_response IS NULL OR TRIM(psalm_response) = '' 
                THEN 1 ELSE 0 END) as missing
        FROM readings 
        WHERE position = 2
        GROUP BY year 
        ORDER BY year
    """).fetchall():
        year_stats.append({
            "year": row["year"],
            "total": row["total"],
            "filled": row["filled"],
            "missing": row["missing"],
            "fill_rate": round(row["filled"] / row["total"] * 100, 1) if row["total"] > 0 else 0
        })

    # Sample unresolved entries
    unresolved = []
    for row in conn.execute("""
        SELECT timestamp, reading
        FROM readings
        WHERE position = 2
          AND (psalm_response IS NULL OR TRIM(psalm_response) = '')
        ORDER BY timestamp
        LIMIT 50
    """).fetchall():
        ts = int(row["timestamp"])
        date = dt.datetime.fromtimestamp(ts, tz=dt.UTC).date()
        unresolved.append({
            "date": str(date),
            "psalm_ref": str(row["reading"]),
        })

    # Generate report
    report = {
        "generated_at": dt.datetime.now(dt.UTC).isoformat(),
        "summary": {
            "total_psalms": total_psalms,
            "filled_psalms": filled_psalms,
            "missing_psalms": missing_psalms,
            "fill_rate_percent": round(filled_psalms / total_psalms * 100, 2),
        },
        "source_breakdown": source_stats,
        "year_statistics": year_stats,
        "sample_unresolved": unresolved,
    }

    # Save to file
    report_path = Path("psalm_backfill_report.json")
    with report_path.open("w", encoding="utf-8") as f:
        json.dump(report, f, indent=2, ensure_ascii=False)

    # Print summary
    print("=" * 70)
    print("PSALM BACKFILL REPORT")
    print("=" * 70)
    print(f"\nOVERALL STATISTICS:")
    print(f"  Total psalm readings:  {total_psalms:5,d}")
    print(f"  Filled responses:      {filled_psalms:5,d} ({report['summary']['fill_rate_percent']}%)")
    print(f"  Missing responses:     {missing_psalms:5,d}")
    
    print(f"\nSOURCE BREAKDOWN:")
    for source, count in sorted(source_stats.items(), key=lambda x: -x[1]):
        print(f"  {source:20s}: {count:5,d} psalms")
    
    print(f"\nYEAR STATISTICS (showing years with missing data):")
    print(f"  {'Year':<6} {'Total':>6} {'Filled':>7} {'Missing':>8} {'Fill %':>8}")
    print(f"  {'-'*6} {'-'*6} {'-'*7} {'-'*8} {'-'*8}")
    for stat in year_stats:
        if stat["missing"] > 0:
            print(f"  {stat['year']:<6} {stat['total']:>6} {stat['filled']:>7} "
                  f"{stat['missing']:>8} {stat['fill_rate']:>7.1f}%")
    
    print(f"\nSAMPLE UNRESOLVED ENTRIES (first 20):")
    for entry in unresolved[:20]:
        print(f"  {entry['date']} | {entry['psalm_ref'][:60]}")
    
    if len(unresolved) > 20:
        print(f"  ... and {len(unresolved) - 20} more (see full report)")
    
    print(f"\n{'='*70}")
    print(f"Full report saved to: {report_path.absolute()}")
    print(f"{'='*70}")

    conn.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
