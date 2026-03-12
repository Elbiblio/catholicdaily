#!/usr/bin/env python3
"""
Backfill Responsorial Psalm refrains into readings.db.

Algorithm:
1) Read each liturgical date from `readings.timestamp` (UTC 8am convention).
2) Fetch official USCCB daily readings page for that date (MMDDYY.cfm).
3) Extract the "Responsorial Psalm" block and parse the refrain line
   (typically prefixed with "R.").
4) Persist results into:
   - readings.psalm_response (for position=2 rows)
   - psalm_responses table (audit + source URL + timestamp)

Usage:
  python scripts/extract_psalm_responses.py --db assets/readings.db --limit 50
  python scripts/extract_psalm_responses.py --db assets/readings.db --force
  python scripts/extract_psalm_responses.py --db assets/readings.db --strategy by-psalm-ref
"""

from __future__ import annotations

import argparse
import datetime as dt
import html
import json
import re
import sqlite3
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


USER_AGENT = (
    "Mozilla/5.0 (compatible; CatholicDailyPsalmBackfill/1.0; "
    "+https://bible.usccb.org)"
)


@dataclass
class PsalmData:
    response: str | None
    alternatives: list[str]
    psalm_reference: str | None
    source_url: str
    raw_excerpt: str | None


@dataclass
class PsalmReadingRow:
    timestamp: int
    reading: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--db",
        default="assets/readings.db",
        help="Path to readings SQLite database.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="Max number of timestamps to process (0 = all).",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Re-fetch even if psalm_responses already has an entry.",
    )
    parser.add_argument(
        "--sleep-ms",
        type=int,
        default=220,
        help="Delay between requests to avoid hammering source site.",
    )
    parser.add_argument(
        "--strategy",
        choices=["by-date", "by-psalm-ref"],
        default="by-psalm-ref",
        help=(
            "Extraction strategy. by-psalm-ref is much faster by resolving "
            "unique psalm references first, then propagating to all dates."
        ),
    )
    parser.add_argument(
        "--validate-samples",
        type=int,
        default=2,
        help=(
            "For by-psalm-ref strategy, fetch this many extra dates per psalm "
            "reference to detect override conflicts."
        ),
    )
    parser.add_argument(
        "--seed-retries",
        type=int,
        default=6,
        help=(
            "For by-psalm-ref strategy, try this many dates for a given psalm "
            "reference before marking it as missing."
        ),
    )
    parser.add_argument(
        "--min-year",
        type=int,
        default=2000,
        help="Skip timestamps older than this year (filters placeholder unix rows).",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    db_path = Path(args.db).resolve()
    if not db_path.exists():
        print(f"Database not found: {db_path}", file=sys.stderr)
        return 1

    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row
    ensure_schema(conn)

    if args.strategy == "by-date":
        timestamps = list(iter_timestamps(conn, args.force, args.min_year))
        if args.limit > 0:
            timestamps = timestamps[: args.limit]
        ok, missing, failed = run_by_date_strategy(
            conn=conn,
            timestamps=timestamps,
            sleep_ms=args.sleep_ms,
        )
    else:
        psalm_rows = list(iter_psalm_rows(conn, args.force, args.min_year))
        if args.limit > 0:
            psalm_rows = psalm_rows[: args.limit]
        ok, missing, failed = run_by_psalm_ref_strategy(
            conn=conn,
            psalm_rows=psalm_rows,
            sleep_ms=args.sleep_ms,
            validate_samples=max(0, args.validate_samples),
            seed_retries=max(1, args.seed_retries),
        )

    conn.commit()
    conn.close()

    print(
        "Done. "
        f"updated={ok}, missing={missing}, failed={failed}"
    )
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
    psalm_columns = {
        row["name"]
        for row in conn.execute("PRAGMA table_info(psalm_responses)").fetchall()
    }
    if "response_alternatives" not in psalm_columns:
        conn.execute("ALTER TABLE psalm_responses ADD COLUMN response_alternatives TEXT")

    columns = {
        row["name"] for row in conn.execute("PRAGMA table_info(readings)").fetchall()
    }
    if "psalm_response" not in columns:
        conn.execute("ALTER TABLE readings ADD COLUMN psalm_response TEXT")
    if "psalm_response_alternatives" not in columns:
        conn.execute("ALTER TABLE readings ADD COLUMN psalm_response_alternatives TEXT")


def iter_timestamps(
    conn: sqlite3.Connection,
    force: bool,
    min_year: int,
) -> Iterable[int]:
    if force:
        rows = conn.execute(
            "SELECT DISTINCT timestamp FROM readings ORDER BY timestamp"
        ).fetchall()
    else:
        rows = conn.execute(
            """
            SELECT DISTINCT r.timestamp
            FROM readings r
            LEFT JOIN psalm_responses p ON p.timestamp = r.timestamp
            WHERE p.timestamp IS NULL
            ORDER BY r.timestamp
            """
        ).fetchall()
    min_ts = int(dt.datetime(min_year, 1, 1, tzinfo=dt.UTC).timestamp())
    return [int(row["timestamp"]) for row in rows if int(row["timestamp"]) >= min_ts]


def iter_psalm_rows(
    conn: sqlite3.Connection,
    force: bool,
    min_year: int,
) -> Iterable[PsalmReadingRow]:
    min_ts = int(dt.datetime(min_year, 1, 1, tzinfo=dt.UTC).timestamp())

    if force:
        rows = conn.execute(
            """
            SELECT timestamp, reading
            FROM readings
            WHERE position = 2 AND timestamp >= ?
            ORDER BY timestamp
            """,
            (min_ts,),
        ).fetchall()
    else:
        rows = conn.execute(
            """
            SELECT r.timestamp, r.reading
            FROM readings r
            LEFT JOIN psalm_responses p ON p.timestamp = r.timestamp
            WHERE r.position = 2
              AND r.timestamp >= ?
              AND p.timestamp IS NULL
            ORDER BY r.timestamp
            """,
            (min_ts,),
        ).fetchall()

    return [
        PsalmReadingRow(timestamp=int(row["timestamp"]), reading=str(row["reading"]))
        for row in rows
    ]


def run_by_date_strategy(
    conn: sqlite3.Connection,
    timestamps: list[int],
    sleep_ms: int,
) -> tuple[int, int, int]:
    print(f"Processing {len(timestamps)} liturgical dates (by-date strategy)")

    ok = 0
    missing = 0
    failed = 0

    for idx, ts in enumerate(timestamps, start=1):
        target_date = dt.datetime.fromtimestamp(ts, tz=dt.UTC).date()
        url = build_usccb_url(target_date)
        print(f"[{idx}/{len(timestamps)}] {target_date.isoformat()} -> {url}")

        try:
            page = fetch(url)
            parsed = extract_psalm_data(page, url)
            if parsed.response:
                persist_psalm(conn, ts, parsed)
                ok += 1
                print(f"  OK: {parsed.response}")
            else:
                persist_psalm(conn, ts, parsed)
                missing += 1
                print("  Missing refrain in parsed content")
        except Exception as exc:  # noqa: BLE001
            failed += 1
            print(f"  ERROR: {exc}")

        time.sleep(max(0, sleep_ms) / 1000.0)

    return ok, missing, failed


def run_by_psalm_ref_strategy(
    conn: sqlite3.Connection,
    psalm_rows: list[PsalmReadingRow],
    sleep_ms: int,
    validate_samples: int,
    seed_retries: int,
) -> tuple[int, int, int]:
    grouped: dict[str, list[int]] = {}
    for row in psalm_rows:
        grouped.setdefault(row.reading, []).append(row.timestamp)

    refs = sorted(grouped.items(), key=lambda item: item[1][0])
    print(
        f"Processing {len(psalm_rows)} dates via {len(refs)} unique psalm references "
        "(by-psalm-ref strategy)"
    )

    known_ref_map = load_known_reference_responses(conn)
    if known_ref_map:
        print(
            f"Loaded {len(known_ref_map)} known reference->response mappings "
            "from existing DB values"
        )

    ok = 0
    missing = 0
    failed = 0

    for idx, (psalm_ref, timestamps) in enumerate(refs, start=1):
        seed_ts = timestamps[0]
        seed_date = dt.datetime.fromtimestamp(seed_ts, tz=dt.UTC).date()
        print(f"[{idx}/{len(refs)}] {psalm_ref} -> seed {seed_date.isoformat()}")

        try:
            known_response = known_ref_map.get(psalm_ref)
            if known_response:
                data = PsalmData(
                    response=known_response,
                    alternatives=[known_response],
                    psalm_reference=psalm_ref,
                    source_url="derived://reference-map",
                    raw_excerpt=None,
                )
                for ts in timestamps:
                    persist_psalm(conn, ts, data)
                    ok += 1
                print(f"  DB map hit: applied to {len(timestamps)} dates")
                continue

            parsed: PsalmData | None = None
            for candidate_ts in timestamps[:seed_retries]:
                candidate_date = dt.datetime.fromtimestamp(
                    candidate_ts, tz=dt.UTC
                ).date()
                candidate_url = build_usccb_url(candidate_date)
                candidate = extract_psalm_data(fetch(candidate_url), candidate_url)
                if candidate.response:
                    parsed = candidate
                    break
                if parsed is None:
                    parsed = candidate

            parsed = parsed or PsalmData(
                response=None,
                alternatives=[],
                psalm_reference=psalm_ref,
                source_url="derived://seed-retry-empty",
                raw_excerpt=None,
            )
            if not parsed.response:
                persist_psalm(conn, seed_ts, parsed)
                missing += 1
                print("  Missing refrain for seed date")
                continue

            if validate_samples > 0 and len(timestamps) > 1:
                conflicts = []
                for ts in timestamps[1 : 1 + validate_samples]:
                    sample_date = dt.datetime.fromtimestamp(ts, tz=dt.UTC).date()
                    sample_url = build_usccb_url(sample_date)
                    sample = extract_psalm_data(fetch(sample_url), sample_url)
                    if sample.response and sample.response != parsed.response:
                        conflicts.append((ts, sample))
                    time.sleep(max(0, sleep_ms) / 1000.0)

                if conflicts:
                    print(
                        "  Conflict detected for this psalm reference; "
                        "falling back to per-date persistence."
                    )
                    for ts in timestamps:
                        target_date = dt.datetime.fromtimestamp(ts, tz=dt.UTC).date()
                        url = build_usccb_url(target_date)
                        item = extract_psalm_data(fetch(url), url)
                        persist_psalm(conn, ts, item)
                        if item.response:
                            ok += 1
                        else:
                            missing += 1
                        time.sleep(max(0, sleep_ms) / 1000.0)
                    continue

            # No conflicts: propagate one resolved response to all dates sharing ref.
            for ts in timestamps:
                persist_psalm(conn, ts, parsed)
                ok += 1
            print(f"  OK: applied to {len(timestamps)} dates")

        except Exception as exc:  # noqa: BLE001
            failed += 1
            print(f"  ERROR: {exc}")

        time.sleep(max(0, sleep_ms) / 1000.0)

    return ok, missing, failed


def build_usccb_url(target_date: dt.date) -> str:
    # USCCB daily URL style: /bible/readings/MMDDYY.cfm
    return f"https://bible.usccb.org/bible/readings/{target_date:%m%d%y}.cfm"


def load_known_reference_responses(conn: sqlite3.Connection) -> dict[str, str]:
    rows = conn.execute(
        """
        SELECT reading, psalm_response
        FROM readings
        WHERE position = 2
          AND psalm_response IS NOT NULL
          AND TRIM(psalm_response) <> ''
        """
    ).fetchall()

    by_ref: dict[str, set[str]] = {}
    for row in rows:
        ref = str(row["reading"])
        response = str(row["psalm_response"]).strip()
        if not response:
            continue
        by_ref.setdefault(ref, set()).add(response)

    result: dict[str, str] = {}
    for ref, responses in by_ref.items():
        if len(responses) == 1:
            result[ref] = next(iter(responses))
    return result


def fetch(url: str) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=25) as resp:
            return resp.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as exc:
        if exc.code == 404:
            return ""
        raise


def extract_psalm_data(page_html: str, source_url: str) -> PsalmData:
    if not page_html.strip():
        return PsalmData(
            response=None,
            alternatives=[],
            psalm_reference=None,
            source_url=source_url,
            raw_excerpt=None,
        )

    text = html_to_text(page_html)
    lines = [normalize_line(line) for line in text.splitlines()]
    lines = [line for line in lines if line]

    start = index_of(lines, lambda s: "responsorial psalm" in s.lower())
    if start < 0:
        return PsalmData(
            response=None,
            alternatives=[],
            psalm_reference=None,
            source_url=source_url,
            raw_excerpt=None,
        )

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
    response = refrains[0] if refrains else None
    psalm_ref = parse_psalm_reference(block)
    excerpt = " | ".join(block[:8]) if block else None

    return PsalmData(
        response=response,
        alternatives=refrains,
        psalm_reference=psalm_ref,
        source_url=source_url,
        raw_excerpt=excerpt,
    )


def parse_refrains(block: list[str]) -> list[str]:
    patterns = [
        re.compile(r"^R\.\s*\([^)]*\)\s*(.+)$", re.IGNORECASE),
        re.compile(r"^R\.\s*(.+)$", re.IGNORECASE),
        re.compile(r"^R/\s*\([^)]*\)\s*(.+)$", re.IGNORECASE),
        re.compile(r"^R/\s*(.+)$", re.IGNORECASE),
        re.compile(r"^Resp\.\s*(.+)$", re.IGNORECASE),
    ]
    seen: set[str] = set()
    ordered: list[str] = []
    for line in block:
        for pattern in patterns:
            m = pattern.match(line)
            if m:
                result = cleanup_response(m.group(1))
                if result and result not in seen:
                    seen.add(result)
                    ordered.append(result)
    return ordered


def parse_psalm_reference(block: list[str]) -> str | None:
    for line in block:
        if re.match(r"^Ps\s+\d+", line, flags=re.IGNORECASE):
            return line
    return None


def cleanup_response(value: str) -> str:
    value = value.strip()
    value = re.sub(r"\s+", " ", value)
    return value.rstrip(";:,")


def html_to_text(raw_html: str) -> str:
    cleaned = re.sub(
        r"(?is)<(script|style).*?>.*?</\1>",
        " ",
        raw_html,
    )
    cleaned = re.sub(r"(?i)<br\s*/?>", "\n", cleaned)
    cleaned = re.sub(r"(?i)</(p|div|li|h1|h2|h3|h4|h5|h6|tr|section)>", "\n", cleaned)
    cleaned = re.sub(r"(?is)<[^>]+>", " ", cleaned)
    cleaned = html.unescape(cleaned)
    return cleaned


def normalize_line(line: str) -> str:
    line = line.replace("\xa0", " ")
    line = re.sub(r"\s+", " ", line)
    return line.strip()


def index_of(items: list[str], predicate) -> int:
    for i, item in enumerate(items):
        if predicate(item):
            return i
    return -1


def persist_psalm(conn: sqlite3.Connection, timestamp: int, data: PsalmData) -> None:
    now = dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat().replace(
        "+00:00",
        "Z",
    )
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
        (
            timestamp,
            data.psalm_reference,
            data.response,
            json.dumps(data.alternatives, ensure_ascii=True),
            data.source_url,
            data.raw_excerpt,
            now,
        ),
    )

    conn.execute(
        """
        UPDATE readings
        SET psalm_response = ?, psalm_response_alternatives = ?
        WHERE timestamp = ? AND position = 2
        """,
        (data.response, json.dumps(data.alternatives, ensure_ascii=True), timestamp),
    )


if __name__ == "__main__":
    raise SystemExit(main())
