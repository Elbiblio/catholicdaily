#!/usr/bin/env python3
"""
Enhanced psalm backfill using tiered source resolver.

Resolution order:
1. USCCB (primary, official source)
2. Cached per-year/cycle (existing database)
3. CatholicGallery (fallback scraper)
4. Unresolved (report for manual review)
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

from psalm_source_resolver import (
    TieredPsalmResolver,
    liturgical_year_for_date,
    sunday_cycle_for_date,
    weekday_cycle_for_date,
)


@dataclass(frozen=True)
class CacheKey:
    psalm_ref: str
    year: int
    sunday_cycle: str
    weekday_cycle: str

    def to_text(self) -> str:
        return f"{self.psalm_ref}|{self.year}|{self.sunday_cycle}|{self.weekday_cycle}"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", default="assets/readings.db")
    parser.add_argument(
        "--years",
        default="2020,2021,2022,2023,2024,2025,2026",
        help="Comma-separated calendar years.",
    )
    parser.add_argument("--script-key", default="backfill_psalm_refrains_tiered")
    parser.add_argument("--no-cursor", action="store_true")
    parser.add_argument("--reset-cursor", action="store_true")
    parser.add_argument("--limit", type=int, default=0, help="Max target rows to process.")
    parser.add_argument("--report", action="store_true", help="Generate detailed resolution report.")
    parser.add_argument("--unresolved-only", action="store_true", help="Only show unresolved entries in report.")
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
    ensure_schema(conn)
    
    if args.reset_cursor and not args.no_cursor:
        for year in years:
            reset_cursor(conn, args.script_key, year)
        conn.commit()

    resolver = TieredPsalmResolver(conn)
    
    rows = load_target_rows(
        conn,
        years,
        use_cursor=not args.no_cursor,
        script_key=args.script_key,
        limit=args.limit,
    )
    
    groups: dict[CacheKey, list[int]] = {}
    by_ts_ref: dict[int, str] = {}
    for row in rows:
        ts = int(row["timestamp"])
        date = dt.datetime.fromtimestamp(ts, tz=dt.UTC).date()
        ref = str(row["reading"]).strip()
        if not ref:
            continue
        key = CacheKey(
            psalm_ref=ref,
            year=date.year,
            sunday_cycle=sunday_cycle_for_date(date),
            weekday_cycle=weekday_cycle_for_date(date),
        )
        groups.setdefault(key, []).append(ts)
        by_ts_ref[ts] = ref

    print(f"Target rows: {len(rows)}")
    print(f"Year/cycle groups: {len(groups)}")

    updated = 0
    missing = 0
    failed = 0
    source_stats: dict[str, int] = {}
    unresolved_entries: list[dict] = []

    for idx, (key, timestamps) in enumerate(
        sorted(groups.items(), key=lambda x: (min(x[1]), x[0].year, x[0].psalm_ref)),
        start=1,
    ):
        # Check if group already has consistent response
        existing = existing_response_for_group(conn, timestamps)
        if existing:
            apply_response(
                conn, timestamps, key.psalm_ref, existing, [existing],
                "cache://existing-group", key.to_text()
            )
            updated += len(timestamps)
            source_stats["existing"] = source_stats.get("existing", 0) + 1
            if not args.no_cursor:
                update_cursor(conn, args.script_key, key.year, max(timestamps))
            continue

        # Use tiered resolver
        sample_date = dt.datetime.fromtimestamp(min(timestamps), tz=dt.UTC).date()
        
        if args.report:
            result, report = resolver.resolve_with_report(
                sample_date, key.psalm_ref, key.year,
                key.sunday_cycle, key.weekday_cycle
            )
        else:
            result = resolver.resolve(
                sample_date, key.psalm_ref, key.year,
                key.sunday_cycle, key.weekday_cycle
            )
            report = {}

        if result:
            apply_response(
                conn, timestamps, key.psalm_ref,
                result.response, result.alternatives,
                result.source_url, key.to_text()
            )
            updated += len(timestamps)
            source_stats[result.source] = source_stats.get(result.source, 0) + 1
            
            if args.report and not args.unresolved_only:
                print(f"  [{idx}/{len(groups)}] {sample_date} {key.psalm_ref[:30]}")
                print(f"    ✓ Resolved via {result.source} (confidence: {result.confidence})")
                if report:
                    print(f"    Sources tried: {report}")
        else:
            missing += len(timestamps)
            if args.report:
                entry = {
                    "date": str(sample_date),
                    "psalm_ref": key.psalm_ref,
                    "year": key.year,
                    "sunday_cycle": key.sunday_cycle,
                    "weekday_cycle": key.weekday_cycle,
                    "attempts": report,
                }
                unresolved_entries.append(entry)
                print(f"  [{idx}/{len(groups)}] {sample_date} {key.psalm_ref[:30]}")
                print(f"    ✗ UNRESOLVED - Sources tried: {report}")

        if not args.no_cursor:
            update_cursor(conn, args.script_key, key.year, max(timestamps))

        if idx % 50 == 0 and not args.report:
            print(f"[{idx}/{len(groups)}] updated={updated} missing={missing} failed={failed}")
            print(f"  Source stats: {source_stats}")
            conn.commit()

    conn.commit()
    conn.close()
    
    print("\n" + "=" * 70)
    print(f"FINAL RESULTS:")
    print(f"  Updated: {updated} rows")
    print(f"  Missing: {missing} rows")
    print(f"  Failed: {failed} rows")
    print(f"\nSource breakdown:")
    for source, count in sorted(source_stats.items(), key=lambda x: -x[1]):
        print(f"  {source:20s}: {count:5d} groups")
    
    if unresolved_entries:
        print(f"\n{len(unresolved_entries)} UNRESOLVED ENTRIES:")
        for entry in unresolved_entries[:20]:  # Show first 20
            print(f"  {entry['date']} | {entry['psalm_ref'][:40]}")
        if len(unresolved_entries) > 20:
            print(f"  ... and {len(unresolved_entries) - 20} more")
        
        # Save full report to file
        report_path = Path("psalm_unresolved_report.json")
        with report_path.open("w", encoding="utf-8") as f:
            json.dump(unresolved_entries, f, indent=2, ensure_ascii=False)
        print(f"\nFull unresolved report saved to: {report_path}")
    
    return 0 if failed == 0 else 2


def ensure_schema(conn: sqlite3.Connection) -> None:
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS psalm_responses (
          timestamp INTEGER PRIMARY KEY,
          psalm_reference TEXT,
          response TEXT,
          response_alternatives TEXT,
          source_url TEXT NOT NULL,
          raw_excerpt TEXT,
          fetched_at TEXT NOT NULL
        )
        """
    )
    cols = {row["name"] for row in conn.execute("PRAGMA table_info(readings)")}
    if "psalm_response" not in cols:
        conn.execute("ALTER TABLE readings ADD COLUMN psalm_response TEXT")
    if "psalm_response_alternatives" not in cols:
        conn.execute("ALTER TABLE readings ADD COLUMN psalm_response_alternatives TEXT")
    if "psalm_response_cache_key" not in cols:
        conn.execute("ALTER TABLE readings ADD COLUMN psalm_response_cache_key TEXT")
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS extraction_cursors (
          script_key TEXT NOT NULL,
          year INTEGER NOT NULL,
          last_timestamp INTEGER NOT NULL DEFAULT 0,
          updated_at TEXT NOT NULL,
          PRIMARY KEY (script_key, year)
        )
        """
    )


def load_target_rows(
    conn: sqlite3.Connection,
    years: list[int],
    use_cursor: bool,
    script_key: str,
    limit: int = 0,
) -> list[sqlite3.Row]:
    out: list[sqlite3.Row] = []
    for year in sorted(years):
        start = int(dt.datetime(year, 1, 1, tzinfo=dt.UTC).timestamp())
        end = int(dt.datetime(year + 1, 1, 1, tzinfo=dt.UTC).timestamp())
        cursor_ts = get_cursor(conn, script_key, year) if use_cursor else 0
        sql = """
          SELECT timestamp, reading, psalm_response
          FROM readings
          WHERE position = 2
            AND timestamp >= ?
            AND timestamp < ?
            AND timestamp > ?
            AND (psalm_response IS NULL OR TRIM(psalm_response) = '')
          ORDER BY timestamp
        """
        rows = conn.execute(sql, (start, end, cursor_ts)).fetchall()
        out.extend(rows)
    out.sort(key=lambda row: int(row["timestamp"]))
    if limit > 0:
        return out[:limit]
    return out


def get_cursor(conn: sqlite3.Connection, script_key: str, year: int) -> int:
    row = conn.execute(
        """
        SELECT last_timestamp
        FROM extraction_cursors
        WHERE script_key = ? AND year = ?
        """,
        (script_key, year),
    ).fetchone()
    return int(row["last_timestamp"]) if row else 0


def update_cursor(
    conn: sqlite3.Connection,
    script_key: str,
    year: int,
    timestamp: int,
) -> None:
    now = dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    conn.execute(
        """
        INSERT INTO extraction_cursors (script_key, year, last_timestamp, updated_at)
        VALUES (?, ?, ?, ?)
        ON CONFLICT(script_key, year) DO UPDATE SET
          last_timestamp = CASE
            WHEN excluded.last_timestamp > extraction_cursors.last_timestamp
            THEN excluded.last_timestamp
            ELSE extraction_cursors.last_timestamp
          END,
          updated_at = excluded.updated_at
        """,
        (script_key, year, timestamp, now),
    )


def reset_cursor(conn: sqlite3.Connection, script_key: str, year: int) -> None:
    conn.execute(
        "DELETE FROM extraction_cursors WHERE script_key = ? AND year = ?",
        (script_key, year),
    )


def existing_response_for_group(conn: sqlite3.Connection, timestamps: list[int]) -> str | None:
    if not timestamps:
        return None
    placeholders = ",".join(["?"] * len(timestamps))
    sql = f"""
      SELECT psalm_response
      FROM readings
      WHERE position = 2
        AND timestamp IN ({placeholders})
        AND psalm_response IS NOT NULL
        AND TRIM(psalm_response) <> ''
    """
    values = [str(row["psalm_response"]).strip() for row in conn.execute(sql, timestamps).fetchall()]
    if not values:
        return None
    common, _ = Counter(values).most_common(1)[0]
    return common


def apply_response(
    conn: sqlite3.Connection,
    timestamps: list[int],
    psalm_ref: str,
    response: str,
    alternatives: list[str],
    source_url: str,
    cache_key: str,
) -> None:
    now = dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    alt_json = json.dumps(alternatives, ensure_ascii=True)
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
              raw_excerpt = excluded.raw_excerpt,
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


if __name__ == "__main__":
    raise SystemExit(main())
