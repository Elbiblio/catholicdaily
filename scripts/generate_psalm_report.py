#!/usr/bin/env python3
"""Generate comprehensive psalm backfill report."""
from __future__ import annotations

import datetime as dt
import json
import sqlite3
from pathlib import Path


def main() -> int:
    print(
        "This legacy psalm report script is retired. "
        "Generate diagnostics from the CSV catalogs instead of readings.db."
    )
    return 1
    
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
