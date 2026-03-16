#!/usr/bin/env python3
from __future__ import annotations

import argparse
import datetime as dt
import json
import shutil
import sqlite3
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", default="assets/readings.db")
    parser.add_argument(
        "--report",
        default="scripts/reports/gospel_acclamation_audit_2025_2027.json",
    )
    parser.add_argument("--backup-dir", default="backups")
    parser.add_argument(
        "--severities",
        default="P1,P2",
        help="Comma-separated severities to apply",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show planned updates without mutating the database",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    db_path = Path(args.db).resolve()
    report_path = Path(args.report).resolve()
    print(
        "This legacy gospel acclamation audit fixer is retired. "
        f"Do not patch {db_path.name}; apply audit fixes to the CSV catalogs and reports like {report_path.name} instead."
    )
    return 1


def build_updates(issues: list[dict], severities: set[str]) -> dict[int, dict]:
    planned: dict[int, dict] = {}
    for issue in issues:
        if issue.get("severity") not in severities:
            continue
        if issue.get("celebration_id") is not None:
            continue
        issue_type = issue.get("type")
        if issue_type not in {
            "missing_stored_acclamation",
            "stored_reference_would_leak_long_text",
            "stored_reference_differs_from_mapped_reference",
        }:
            continue

        details = issue.get("details") or {}
        mapped_text = (details.get("mapped_text") or "").strip()
        if not mapped_text:
            continue
        if mapped_text.lower().startswith("reading text unavailable"):
            continue

        date_text = issue.get("date")
        gospel_reference = issue.get("gospel_reference")
        if not date_text or not gospel_reference:
            continue

        timestamp = timestamp_for_date(date_text)
        existing = planned.get(timestamp)
        payload = {
            "date": date_text,
            "gospel_reference": gospel_reference,
            "stored_acclamation": details.get("stored_acclamation"),
            "mapped_reference": details.get("mapped_reference"),
            "mapped_text": mapped_text,
            "severity": issue.get("severity"),
            "type": issue_type,
        }

        if existing is None:
            planned[timestamp] = payload
            continue

        if priority_of(issue_type) < priority_of(existing["type"]):
            planned[timestamp] = payload

    return planned


def priority_of(issue_type: str) -> int:
    order = {
        "stored_reference_would_leak_long_text": 0,
        "stored_reference_differs_from_mapped_reference": 1,
        "missing_stored_acclamation": 2,
    }
    return order.get(issue_type, 99)


def timestamp_for_date(date_text: str) -> int:
    year, month, day = [int(part) for part in date_text.split("-")]
    return int(dt.datetime(year, month, day, 8, 0, 0, tzinfo=dt.UTC).timestamp())


def apply_updates(conn: sqlite3.Connection, planned_updates: dict[int, dict]) -> int:
    updated = 0
    conn.row_factory = sqlite3.Row
    for timestamp, payload in sorted(planned_updates.items()):
        row = conn.execute(
            """
            SELECT position, reading, gospel_acclamation
            FROM readings
            WHERE timestamp = ?
              AND reading = ?
            """,
            (timestamp, payload["gospel_reference"]),
        ).fetchone()
        if row is None:
            continue
        reading = str(row["reading"]).strip()
        if reading != payload["gospel_reference"]:
            continue

        cursor = conn.execute(
            """
            UPDATE readings
            SET gospel_acclamation = ?
            WHERE timestamp = ? AND reading = ?
            """,
            (payload["mapped_text"], timestamp, payload["gospel_reference"]),
        )
        updated += cursor.rowcount if cursor.rowcount != -1 else 0
    return updated


if __name__ == "__main__":
    raise SystemExit(main())
