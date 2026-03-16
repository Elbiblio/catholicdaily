#!/usr/bin/env python3
from __future__ import annotations

import argparse
import datetime as dt
import re
import sqlite3
import sys
import urllib.error
import urllib.request
from pathlib import Path
from bs4 import BeautifulSoup

USER_AGENT = (
    "Mozilla/5.0 (compatible; CatholicDailyGospelAcclamation/1.0; "
    "+https://bible.usccb.org)"
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", default="assets/readings.db")
    parser.add_argument("--start-year", type=int, default=2020)
    parser.add_argument("--end-year", type=int, default=2026)
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument("--script-key", default="extract_gospel_acclamations")
    parser.add_argument("--no-cursor", action="store_true")
    parser.add_argument("--reset-cursor", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    db_path = Path(args.db).resolve()
    print(
        "This legacy gospel acclamation extractor is retired. "
        f"The app no longer updates {db_path.name}; maintain acclamations in the CSV catalogs instead."
    )
    return 1


def ensure_schema(conn: sqlite3.Connection) -> None:
    cols = {row["name"] for row in conn.execute("PRAGMA table_info(readings)").fetchall()}
    if "gospel_acclamation" not in cols:
        conn.execute("ALTER TABLE readings ADD COLUMN gospel_acclamation TEXT")
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


def load_targets(
    conn: sqlite3.Connection,
    start_year: int,
    end_year: int,
    force: bool,
    use_cursor: bool,
    script_key: str,
) -> list[int]:
    all_targets: list[int] = []
    for year in range(start_year, end_year + 1):
        start_ts = int(dt.datetime(year, 1, 1, tzinfo=dt.UTC).timestamp())
        end_ts = int(dt.datetime(year + 1, 1, 1, tzinfo=dt.UTC).timestamp())
        cursor_ts = get_cursor(conn, script_key, year) if use_cursor else 0
        start_bound = max(start_ts, cursor_ts + 1)
        if force:
            rows = conn.execute(
                """
                SELECT DISTINCT timestamp
                FROM readings
                WHERE position = 4
                  AND timestamp >= ?
                  AND timestamp < ?
                ORDER BY timestamp
                """,
                (start_bound, end_ts),
            ).fetchall()
        else:
            rows = conn.execute(
                """
                SELECT DISTINCT timestamp
                FROM readings
                WHERE position = 4
                  AND timestamp >= ?
                  AND timestamp < ?
                  AND (gospel_acclamation IS NULL OR TRIM(gospel_acclamation) = '')
                ORDER BY timestamp
                """,
                (start_bound, end_ts),
            ).fetchall()
        all_targets.extend(int(row["timestamp"]) for row in rows)
    return all_targets


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
    now = dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat().replace(
        "+00:00", "Z"
    )
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


def reset_cursor(
    conn: sqlite3.Connection,
    script_key: str,
    start_year: int,
    end_year: int,
) -> None:
    conn.execute(
        """
        DELETE FROM extraction_cursors
        WHERE script_key = ?
          AND year >= ?
          AND year <= ?
        """,
        (script_key, start_year, end_year),
    )
    conn.commit()


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
    soup = BeautifulSoup(page_html, "html.parser")

    heading = None
    for h in soup.find_all(["h2", "h3", "h4"]):
        title = normalize_line(h.get_text(" ", strip=True)).lower()
        if "verse before the gospel" in title or title == "alleluia":
            heading = h
            break

    if heading is None:
        return None

    block_nodes = []
    current = heading.find_next_sibling()
    while current is not None:
        if current.name in {"h2", "h3", "h4"}:
            nxt = normalize_line(current.get_text(" ", strip=True)).lower()
            if "gospel" in nxt or "reading" in nxt:
                break
        block_nodes.append(current)
        current = current.find_next_sibling()

    raw_lines = [normalize_line(heading.get_text(" ", strip=True))]
    for node in block_nodes:
        text = normalize_line(node.get_text("\n", strip=True))
        if text:
            raw_lines.extend([normalize_line(line) for line in text.split("\n") if normalize_line(line)])

    cleaned = []
    for line in raw_lines:
        lower = line.lower()
        if (
            "verse before the gospel" in lower
            or lower == "alleluia"
            or re.match(r"^[a-z]{2,}\s+\d+[:\d,\s-]+$", line)
            or re.match(r"^(john|matt|mark|luke|mt|mk|lk|jn)\s+\d+", lower)
            or lower.startswith("r.")
            or lower.startswith("v.")
        ):
            continue
        cleaned.append(line)

    if not cleaned:
        return None
    return normalize_line(" ".join(cleaned))


def normalize_line(line: str) -> str:
    return re.sub(r"\s+", " ", line.replace("\xa0", " ")).strip()


if __name__ == "__main__":
    raise SystemExit(main())
