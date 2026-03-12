#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sqlite3
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", default="assets/readings.db")
    parser.add_argument("--out", default="assets/data/readings_rows.json")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    db_path = Path(args.db).resolve()
    out_path = Path(args.out).resolve()

    if not db_path.exists():
        print(f"DB not found: {db_path}")
        return 1

    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row

    has_psalm_response = any(
        row["name"] == "psalm_response"
        for row in conn.execute("PRAGMA table_info(readings)").fetchall()
    )
    has_gospel_acclamation = any(
        row["name"] == "gospel_acclamation"
        for row in conn.execute("PRAGMA table_info(readings)").fetchall()
    )
    sql = (
        "SELECT timestamp, position, reading, "
        + ("psalm_response, " if has_psalm_response else "NULL AS psalm_response, ")
        + (
            "gospel_acclamation "
            if has_gospel_acclamation
            else "NULL AS gospel_acclamation "
        )
        + "FROM readings ORDER BY timestamp, position"
    )
    if not has_psalm_response and not has_gospel_acclamation:
      sql = (
        "SELECT timestamp, position, reading, "
        "NULL AS psalm_response, NULL AS gospel_acclamation "
        "FROM readings ORDER BY timestamp, position"
      )
    rows = conn.execute(sql).fetchall()
    conn.close()

    payload = [
        {
            "timestamp": int(row["timestamp"]),
            "position": int(row["position"]),
            "reading": row["reading"],
            "psalm_response": row["psalm_response"],
            "gospel_acclamation": row["gospel_acclamation"],
        }
        for row in rows
    ]

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(payload, ensure_ascii=True), encoding="utf-8")
    print(f"Wrote {len(payload)} rows to {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
