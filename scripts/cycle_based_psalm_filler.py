#!/usr/bin/env python3
"""
Cycle-based psalm response filler for historical/future dates.

Strategy: Use existing psalm responses from same liturgical cycle (A/B/C, I/II)
and same psalm reference to fill missing entries.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import sqlite3
import sys
from collections import Counter
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class CycleKey:
    psalm_ref: str
    sunday_cycle: str
    weekday_cycle: str

    def to_text(self) -> str:
        return f"{self.psalm_ref}|{self.sunday_cycle}|{self.weekday_cycle}"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", default="assets/readings.db")
    parser.add_argument(
        "--years",
        default="2000,2001,2002,2003,2004,2005,2006,2007,2008,2009,2010,2011,2012,2013,2027,2028,2029,2030,2031,2032,2033,2034,2035,2036,2037,2038",
        help="Comma-separated calendar years to fill.",
    )
    parser.add_argument("--dry-run", action="store_true", help="Don't write to database.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    db_path = Path(args.db).resolve()
    if not db_path.exists():
        print(f"DB not found: {db_path}", file=sys.stderr)
        return 1

    years = [int(y.strip()) for y in args.years.split(",") if y.strip()]
    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row

    print("Building cycle-based psalm response index...")
    cycle_index = build_cycle_index(conn)
    print(f"  Index contains {len(cycle_index)} unique cycle keys")

    rows = load_target_rows(conn, years)
    print(f"\nTarget rows to fill: {len(rows)}")

    groups: dict[CycleKey, list[int]] = {}
    for row in rows:
        ts = int(row["timestamp"])
        date = dt.datetime.fromtimestamp(ts, tz=dt.UTC).date()
        ref = str(row["reading"]).strip()
        if not ref:
            continue
        
        key = CycleKey(
            psalm_ref=ref,
            sunday_cycle=sunday_cycle_for_date(date),
            weekday_cycle=weekday_cycle_for_date(date),
        )
        groups.setdefault(key, []).append(ts)

    print(f"Grouped into {len(groups)} unique cycle keys")

    updated = 0
    missing = 0

    for idx, (key, timestamps) in enumerate(
        sorted(groups.items(), key=lambda x: (min(x[1]), x[0].psalm_ref)),
        start=1,
    ):
        if key in cycle_index:
            response, alternatives = cycle_index[key]
            if not args.dry_run:
                apply_response(conn, timestamps, key.psalm_ref, response, alternatives, key.to_text())
            updated += len(timestamps)
            
            if idx % 100 == 0:
                sample_date = dt.datetime.fromtimestamp(min(timestamps), tz=dt.UTC).date()
                print(f"  [{idx}/{len(groups)}] {sample_date} | {key.psalm_ref[:40]}")
                print(f"    ✓ Filled from cycle: {key.sunday_cycle}/{key.weekday_cycle}")
        else:
            missing += len(timestamps)
            if missing <= 20:  # Show first 20 unresolved
                sample_date = dt.datetime.fromtimestamp(min(timestamps), tz=dt.UTC).date()
                print(f"  [{idx}/{len(groups)}] {sample_date} | {key.psalm_ref[:40]}")
                print(f"    ✗ No cycle match: {key.sunday_cycle}/{key.weekday_cycle}")

        if idx % 200 == 0 and not args.dry_run:
            conn.commit()

    if not args.dry_run:
        conn.commit()
    conn.close()

    print("\n" + "=" * 70)
    print(f"FINAL RESULTS:")
    print(f"  Updated: {updated} rows")
    print(f"  Missing: {missing} rows (no cycle match found)")
    
    if args.dry_run:
        print("\n  (DRY RUN - no changes written to database)")

    return 0


def build_cycle_index(conn: sqlite3.Connection) -> dict[CycleKey, tuple[str, list[str]]]:
    """Build index of psalm responses by cycle key from existing data."""
    index: dict[CycleKey, list[tuple[str, list[str]]]] = {}
    
    rows = conn.execute("""
        SELECT timestamp, reading, psalm_response, psalm_response_alternatives
        FROM readings
        WHERE position = 2
          AND psalm_response IS NOT NULL
          AND TRIM(psalm_response) <> ''
    """).fetchall()

    for row in rows:
        ts = int(row["timestamp"])
        date = dt.datetime.fromtimestamp(ts, tz=dt.UTC).date()
        ref = str(row["reading"]).strip()
        response = str(row["psalm_response"]).strip()
        
        alternatives = []
        if row["psalm_response_alternatives"]:
            try:
                alternatives = json.loads(row["psalm_response_alternatives"])
            except Exception:
                pass

        key = CycleKey(
            psalm_ref=ref,
            sunday_cycle=sunday_cycle_for_date(date),
            weekday_cycle=weekday_cycle_for_date(date),
        )
        
        index.setdefault(key, []).append((response, alternatives))

    # Consolidate to most common response per key
    consolidated: dict[CycleKey, tuple[str, list[str]]] = {}
    for key, entries in index.items():
        responses = [e[0] for e in entries]
        most_common, _ = Counter(responses).most_common(1)[0]
        
        # Get alternatives from the most common response
        alts = []
        for resp, alt_list in entries:
            if resp == most_common:
                alts = alt_list
                break
        
        consolidated[key] = (most_common, alts)

    return consolidated


def load_target_rows(conn: sqlite3.Connection, years: list[int]) -> list[sqlite3.Row]:
    out: list[sqlite3.Row] = []
    for year in sorted(years):
        start = int(dt.datetime(year, 1, 1, tzinfo=dt.UTC).timestamp())
        end = int(dt.datetime(year + 1, 1, 1, tzinfo=dt.UTC).timestamp())
        sql = """
          SELECT timestamp, reading
          FROM readings
          WHERE position = 2
            AND timestamp >= ?
            AND timestamp < ?
            AND (psalm_response IS NULL OR TRIM(psalm_response) = '')
          ORDER BY timestamp
        """
        rows = conn.execute(sql, (start, end)).fetchall()
        out.extend(rows)
    return out


def apply_response(
    conn: sqlite3.Connection,
    timestamps: list[int],
    psalm_ref: str,
    response: str,
    alternatives: list[str],
    cache_key: str,
) -> None:
    now = dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    alt_json = json.dumps(alternatives, ensure_ascii=True)
    source_url = f"cycle://{cache_key}"
    
    for ts in timestamps:
        conn.execute(
            """
            INSERT INTO psalm_responses (
              timestamp, psalm_reference, response, response_alternatives, source_url, raw_excerpt, fetched_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(timestamp) DO UPDATE SET
              psalm_reference = excluded.psalm_reference,
              response = excluded.response,
              response_alternatives = excluded.response_alternatives,
              source_url = excluded.source_url,
              fetched_at = excluded.fetched_at
            """,
            (ts, psalm_ref, response, alt_json, source_url, None, now),
        )
        conn.execute(
            """
            UPDATE readings
            SET psalm_response = ?,
                psalm_response_alternatives = ?,
                psalm_response_cache_key = ?
            WHERE timestamp = ? AND position = 2
            """,
            (response, alt_json, cache_key, ts),
        )


def liturgical_year_for_date(date: dt.date) -> int:
    advent = calculate_advent_start(date.year)
    return date.year + 1 if date >= advent else date.year


def sunday_cycle_for_date(date: dt.date) -> str:
    year = liturgical_year_for_date(date)
    cycles = ["A", "B", "C"]
    return cycles[(year + 1) % 3]


def weekday_cycle_for_date(date: dt.date) -> str:
    year = liturgical_year_for_date(date)
    return "II" if year % 2 == 0 else "I"


def calculate_advent_start(year: int) -> dt.date:
    christmas = dt.date(year, 12, 25)
    days_to_prev_sunday = (christmas.weekday() + 1) % 7
    return christmas - dt.timedelta(days=days_to_prev_sunday + 21)


if __name__ == "__main__":
    raise SystemExit(main())
