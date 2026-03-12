#!/usr/bin/env python3
from __future__ import annotations

import argparse
import datetime as dt
import html
import re
import sqlite3
import sys
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path

USER_AGENT = (
    "Mozilla/5.0 (compatible; CatholicDailyGospelAcclamationCycle/1.0; "
    "+https://bible.usccb.org)"
)


@dataclass(frozen=True)
class CacheKey:
    gospel_ref: str
    year: int
    sunday_cycle: str
    weekday_cycle: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", default="assets/readings.db")
    parser.add_argument("--years", default="2020,2021,2022,2023,2024,2025,2026")
    parser.add_argument("--seed-retries", type=int, default=8)
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

    rows = load_rows(conn, years)
    groups: dict[CacheKey, list[int]] = {}
    for row in rows:
        ts = int(row["timestamp"])
        date = dt.datetime.fromtimestamp(ts, tz=dt.UTC).date()
        ref = str(row["reading"]).strip()
        if not ref:
            continue
        key = CacheKey(
            gospel_ref=ref,
            year=date.year,
            sunday_cycle=sunday_cycle_for_date(date),
            weekday_cycle=weekday_cycle_for_date(date),
        )
        groups.setdefault(key, []).append(ts)

    print(f"Target rows: {len(rows)}")
    print(f"Gospel year/cycle groups: {len(groups)}")

    updated = 0
    missing = 0
    for idx, (key, timestamps) in enumerate(sorted(groups.items(), key=lambda x: (x[0].year, x[0].gospel_ref)), start=1):
        existing = existing_value(conn, timestamps)
        if existing:
            apply_value(conn, timestamps, existing, key)
            updated += len(timestamps)
            continue

        acclamation = None
        for ts in timestamps[: max(1, args.seed_retries)]:
            date = dt.datetime.fromtimestamp(ts, tz=dt.UTC).date()
            page = fetch(build_usccb_url(date))
            acclamation = extract_gospel_acclamation(page)
            if acclamation:
                break

        if not acclamation:
            missing += len(timestamps)
            continue

        apply_value(conn, timestamps, acclamation, key)
        updated += len(timestamps)
        if idx % 100 == 0:
            print(f"[{idx}/{len(groups)}] updated={updated} missing={missing}")

    conn.commit()
    conn.close()
    print(f"Done. updated={updated} missing={missing}")
    return 0


def ensure_schema(conn: sqlite3.Connection) -> None:
    cols = {row["name"] for row in conn.execute("PRAGMA table_info(readings)")}
    if "gospel_acclamation" not in cols:
        conn.execute("ALTER TABLE readings ADD COLUMN gospel_acclamation TEXT")
    if "gospel_acclamation_cache_key" not in cols:
        conn.execute("ALTER TABLE readings ADD COLUMN gospel_acclamation_cache_key TEXT")


def load_rows(conn: sqlite3.Connection, years: list[int]) -> list[sqlite3.Row]:
    ranges = []
    for year in years:
        start = int(dt.datetime(year, 1, 1, tzinfo=dt.UTC).timestamp())
        end = int(dt.datetime(year + 1, 1, 1, tzinfo=dt.UTC).timestamp())
        ranges.append((start, end))
    where = " OR ".join(["(timestamp >= ? AND timestamp < ?)"] * len(ranges))
    args = [v for pair in ranges for v in pair]
    sql = f"""
      SELECT timestamp, reading, gospel_acclamation
      FROM readings
      WHERE position = 4
        AND ({where})
      ORDER BY timestamp
    """
    return conn.execute(sql, args).fetchall()


def existing_value(conn: sqlite3.Connection, timestamps: list[int]) -> str | None:
    placeholders = ",".join(["?"] * len(timestamps))
    sql = f"""
      SELECT gospel_acclamation
      FROM readings
      WHERE position = 4
        AND timestamp IN ({placeholders})
        AND gospel_acclamation IS NOT NULL
        AND TRIM(gospel_acclamation) <> ''
      LIMIT 1
    """
    row = conn.execute(sql, timestamps).fetchone()
    return str(row["gospel_acclamation"]).strip() if row else None


def apply_value(conn: sqlite3.Connection, timestamps: list[int], acclamation: str, key: CacheKey) -> None:
    key_text = f"{key.gospel_ref}|{key.year}|{key.sunday_cycle}|{key.weekday_cycle}"
    for ts in timestamps:
        conn.execute(
            """
            UPDATE readings
            SET gospel_acclamation = ?,
                gospel_acclamation_cache_key = ?
            WHERE timestamp = ? AND position = 4
            """,
            (acclamation, key_text, ts),
        )


def build_usccb_url(date: dt.date) -> str:
    return f"https://bible.usccb.org/bible/readings/{date:%m%d%y}.cfm"


def fetch(url: str) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=25) as resp:
            return resp.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as exc:
        if exc.code == 404:
            return ""
        raise


def extract_gospel_acclamation(page_html: str) -> str | None:
    if not page_html.strip():
        return None
    text = html_to_text(page_html)
    lines = [normalize_line(line) for line in text.splitlines()]
    lines = [line for line in lines if line]

    start = index_of(lines, lambda s: "verse before the gospel" in s.lower())
    if start < 0:
        return None
    stop = len(lines)
    for i in range(start + 1, len(lines)):
        low = lines[i].lower()
        if low == "gospel" or low.startswith("gospel "):
            stop = i
            break
    block = lines[start:stop]
    cleaned: list[str] = []
    for line in block:
        low = line.lower()
        if (
            "verse before the gospel" in low
            or re.match(r"^[a-z]{2,}\s+\d+[:\d,\s-]+$", line)
            or low.startswith("r.")
            or low.startswith("v.")
        ):
            continue
        cleaned.append(line)
    out = " ".join(cleaned).strip()
    return out or None


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

