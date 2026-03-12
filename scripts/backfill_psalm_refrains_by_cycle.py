#!/usr/bin/env python3
from __future__ import annotations

import argparse
import datetime as dt
import html
import json
import re
import sqlite3
import sys
import urllib.error
import urllib.request
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

USER_AGENT = (
    "Mozilla/5.0 (compatible; CatholicDailyPsalmCycleBackfill/1.0; "
    "+https://bible.usccb.org)"
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
    parser.add_argument("--seed-retries", type=int, default=8)
    parser.add_argument("--script-key", default="backfill_psalm_refrains_by_cycle")
    parser.add_argument("--no-cursor", action="store_true")
    parser.add_argument("--reset-cursor", action="store_true")
    parser.add_argument("--limit", type=int, default=0, help="Max target rows to process.")
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

    for idx, (key, timestamps) in enumerate(
        sorted(groups.items(), key=lambda x: (min(x[1]), x[0].year, x[0].psalm_ref)),
        start=1,
    ):
        existing = existing_response_for_group(conn, timestamps)
        if existing:
            apply_response(conn, timestamps, key.psalm_ref, existing, [existing], "cache://existing-group", key.to_text())
            updated += len(timestamps)
            if not args.no_cursor:
                update_cursor(conn, args.script_key, key.year, max(timestamps))
            continue

        resolved = None
        for ts in timestamps[: max(1, args.seed_retries)]:
            date = dt.datetime.fromtimestamp(ts, tz=dt.UTC).date()
            url = build_usccb_url(date)
            try:
                page = fetch(url)
                response, alternatives = extract_refrain(page)
                if response:
                    resolved = (response, alternatives, url)
                    break
            except Exception:
                continue

        if not resolved:
            missing += len(timestamps)
            if not args.no_cursor:
                update_cursor(conn, args.script_key, key.year, max(timestamps))
            continue

        response, alternatives, source_url = resolved
        apply_response(conn, timestamps, key.psalm_ref, response, alternatives, source_url, key.to_text())
        updated += len(timestamps)
        if not args.no_cursor:
            update_cursor(conn, args.script_key, key.year, max(timestamps))

        if idx % 50 == 0:
            print(f"[{idx}/{len(groups)}] updated={updated} missing={missing} failed={failed}")
            conn.commit()

    conn.commit()
    conn.close()
    print(f"Done. updated={updated} missing={missing} failed={failed}")
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


def build_usccb_url(target_date: dt.date) -> str:
    return f"https://bible.usccb.org/bible/readings/{target_date:%m%d%y}.cfm"


def fetch(url: str) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=25) as resp:
            return resp.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as exc:
        if exc.code == 404:
            return ""
        raise


def extract_refrain(page_html: str) -> tuple[str | None, list[str]]:
    if not page_html.strip():
        return None, []
    text = html_to_text(page_html)
    lines = [normalize_line(line) for line in text.splitlines()]
    lines = [line for line in lines if line]

    start = index_of(lines, lambda s: "responsorial psalm" in s.lower())
    if start < 0:
        return None, []
    stop = len(lines)
    for i in range(start + 1, len(lines)):
        lower = lines[i].lower()
        if (
            "reading ii" in lower
            or re.search(r"\breading\s+2\b", lower)
            or "gospel" in lower
            or "alleluia" in lower
            or "verse before the gospel" in lower
        ):
            stop = i
            break
    block = lines[start:stop]
    refrains = parse_refrains(block)
    return (refrains[0] if refrains else None, refrains)


def parse_refrains(block: list[str]) -> list[str]:
    patterns = [
        re.compile(r"^R\.\s*\([^)]*\)\s*(.+)$", re.IGNORECASE),
        re.compile(r"^R\.\s*(.+)$", re.IGNORECASE),
        re.compile(r"^R/\s*\([^)]*\)\s*(.+)$", re.IGNORECASE),
        re.compile(r"^R/\s*(.+)$", re.IGNORECASE),
        re.compile(r"^Resp\.\s*(.+)$", re.IGNORECASE),
    ]
    seen: set[str] = set()
    out: list[str] = []
    for line in block:
        for pat in patterns:
            m = pat.match(line)
            if not m:
                continue
            text = cleanup_response(m.group(1))
            if text and text not in seen:
                seen.add(text)
                out.append(text)
    return out


def cleanup_response(value: str) -> str:
    value = re.sub(r"\s+", " ", value).strip()
    return value.rstrip(";:,")


def html_to_text(raw_html: str) -> str:
    cleaned = re.sub(r"(?is)<(script|style).*?>.*?</\1>", " ", raw_html)
    cleaned = re.sub(r"(?i)<br\s*/?>", "\n", cleaned)
    cleaned = re.sub(r"(?i)</(p|div|li|h1|h2|h3|h4|h5|h6|tr|section)>", "\n", cleaned)
    cleaned = re.sub(r"(?is)<[^>]+>", " ", cleaned)
    return html.unescape(cleaned)


def normalize_line(line: str) -> str:
    return re.sub(r"\s+", " ", line.replace("\xa0", " ")).strip()


def index_of(items: list[str], pred) -> int:
    for i, item in enumerate(items):
        if pred(item):
            return i
    return -1


def _liturgical_year_for_date(date: dt.date) -> int:
    advent = _calculate_advent_start(date.year)
    return date.year + 1 if date >= advent else date.year


def sunday_cycle_for_date(date: dt.date) -> str:
    year = _liturgical_year_for_date(date)
    cycles = ["A", "B", "C"]
    return cycles[(year + 1) % 3]


def weekday_cycle_for_date(date: dt.date) -> str:
    year = _liturgical_year_for_date(date)
    return "II" if year % 2 == 0 else "I"


def _calculate_advent_start(year: int) -> dt.date:
    christmas = dt.date(year, 12, 25)
    days_to_prev_sunday = (christmas.weekday() + 1) % 7
    return christmas - dt.timedelta(days=days_to_prev_sunday + 21)


if __name__ == "__main__":
    raise SystemExit(main())
