#!/usr/bin/env python3
"""
Backfill readings references from Jesuit Ordo day endpoint into readings.db.

Source endpoint:
  https://ordo.jesuits.org/ordo_day_dcs.php?year=YYYY&month=M&day=D
"""

from __future__ import annotations

import argparse
import concurrent.futures as futures
import datetime as dt
import html
import re
import sqlite3
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path

USER_AGENT = (
    "Mozilla/5.0 (compatible; CatholicDailyReadingsBackfill/1.0; "
    "+https://ordo.jesuits.org)"
)


@dataclass
class ParsedDay:
    date: dt.date
    references: dict[int, str] | None
    error: str | None = None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", default="assets/readings.db")
    parser.add_argument("--start-year", type=int, default=2000)
    parser.add_argument("--end-year", type=int, default=2038)
    parser.add_argument("--workers", type=int, default=14)
    parser.add_argument("--sleep-ms", type=int, default=0)
    parser.add_argument("--retries", type=int, default=2)
    parser.add_argument(
        "--force-all",
        action="store_true",
        help="Rebuild every date in range, not just missing/incomplete dates.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    db_path = Path(args.db).resolve()
    if not db_path.exists():
        print(f"DB not found: {db_path}", file=sys.stderr)
        return 1

    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row

    targets = build_targets(
      conn=conn,
      start_year=args.start_year,
      end_year=args.end_year,
      force_all=args.force_all,
    )
    print(f"Target dates: {len(targets)}")
    if not targets:
        conn.close()
        return 0

    ok = 0
    failed = 0
    skipped = 0
    last_commit = time.time()

    with futures.ThreadPoolExecutor(max_workers=max(1, args.workers)) as ex:
        jobs = {
            ex.submit(fetch_and_parse_day, date, args.retries): date for date in targets
        }
        for idx, job in enumerate(futures.as_completed(jobs), start=1):
            result = job.result()
            if result.references is None:
                failed += 1
                print(f"[{idx}/{len(jobs)}] {result.date} ERROR {result.error}")
                continue

            if not result.references:
                skipped += 1
                print(f"[{idx}/{len(jobs)}] {result.date} SKIP no references")
                continue

            upsert_day(conn, result.date, result.references)
            ok += 1
            if idx % 50 == 0:
                print(f"[{idx}/{len(jobs)}] progress ok={ok} failed={failed} skipped={skipped}")
            if time.time() - last_commit > 5:
                conn.commit()
                last_commit = time.time()

            if args.sleep_ms > 0:
                time.sleep(args.sleep_ms / 1000.0)

    conn.commit()
    conn.close()
    print(f"Done. updated={ok} failed={failed} skipped={skipped}")
    return 0 if failed == 0 else 2


def build_targets(
    conn: sqlite3.Connection,
    start_year: int,
    end_year: int,
    force_all: bool,
) -> list[dt.date]:
    if force_all:
        return list(iter_dates(start_year, end_year))

    rows = conn.execute(
        "SELECT timestamp, position FROM readings WHERE timestamp >= ?",
        (utc_timestamp(dt.date(start_year, 1, 1)),),
    ).fetchall()
    by_ts: dict[int, set[int]] = {}
    for row in rows:
        ts = int(row["timestamp"])
        pos = int(row["position"])
        by_ts.setdefault(ts, set()).add(pos)

    targets: list[dt.date] = []
    for day in iter_dates(start_year, end_year):
        ts = utc_timestamp(day)
        positions = by_ts.get(ts, set())
        if not positions:
            targets.append(day)
            continue
        if not ({1, 2, 4}.issubset(positions)):
            targets.append(day)

    return targets


def iter_dates(start_year: int, end_year: int):
    day = dt.date(start_year, 1, 1)
    end = dt.date(end_year, 12, 31)
    while day <= end:
        yield day
        day += dt.timedelta(days=1)


def fetch_and_parse_day(day: dt.date, retries: int) -> ParsedDay:
    last_error = None
    for _ in range(retries + 1):
        try:
            url = (
                f"https://ordo.jesuits.org/ordo_day_dcs.php?"
                f"year={day.year}&month={day.month}&day={day.day}"
            )
            html_text = fetch(url)
            refs = parse_references(html_text)
            return ParsedDay(date=day, references=refs)
        except Exception as exc:  # noqa: BLE001
            last_error = str(exc)
    return ParsedDay(date=day, references=None, error=last_error or "unknown")


def fetch(url: str) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=35) as resp:
        return resp.read().decode("utf-8", errors="replace")


def parse_references(page_html: str) -> dict[int, str]:
    text = html.unescape(page_html)
    text = text.replace("\xa0", " ")
    match = re.search(r"\[[0-9A-Za-z]+\]\s*([^<]+)\.", text, flags=re.IGNORECASE)
    if not match:
        return {}

    segment = normalize_space(match.group(1))
    parts = [normalize_reference(part) for part in segment.split(";")]
    parts = [part for part in parts if part]
    if len(parts) < 2:
        return {}

    # First, Psalm, Gospel are required in our app model. Second reading optional.
    first = parts[0]
    psalm_idx = next((i for i, p in enumerate(parts) if p.startswith("Ps ")), 1)
    psalm = parts[psalm_idx] if psalm_idx < len(parts) else parts[1]
    gospel = parts[-1]
    middle = [p for i, p in enumerate(parts) if i not in (0, psalm_idx, len(parts) - 1)]

    out = {
        1: first,
        2: psalm,
        4: gospel,
    }
    if middle:
        out[3] = middle[0]
    return out


def normalize_reference(value: str) -> str:
    val = normalize_space(value)
    if " or " in val.lower():
        val = re.split(r"\s+or\s+", val, flags=re.IGNORECASE)[0].strip()
    val = re.sub(r"\s*:\s*", ":", val)
    val = re.sub(r"\s*;\s*", "; ", val)
    val = re.sub(r"\s*,\s*", ", ", val)
    val = re.sub(r"\s+", " ", val).strip()

    # Normalize common gospel abbreviations to app aliases.
    repl = {
        r"^Lk\b": "Luke",
        r"^Mk\b": "Mark",
        r"^Mt\b": "Matt",
        r"^Jn\b": "John",
    }
    for pattern, replacement in repl.items():
        val = re.sub(pattern, replacement, val)

    return val


def normalize_space(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def upsert_day(conn: sqlite3.Connection, day: dt.date, refs: dict[int, str]) -> None:
    ts = utc_timestamp(day)
    conn.execute("DELETE FROM readings WHERE timestamp = ?", (ts,))
    for position in sorted(refs):
        conn.execute(
            "INSERT INTO readings (timestamp, reading, position) VALUES (?, ?, ?)",
            (ts, refs[position], position),
        )


def utc_timestamp(day: dt.date) -> int:
    return int(dt.datetime(day.year, day.month, day.day, 8, tzinfo=dt.UTC).timestamp())


if __name__ == "__main__":
    raise SystemExit(main())

