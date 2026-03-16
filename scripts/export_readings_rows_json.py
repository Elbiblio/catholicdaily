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
    print(
        "This legacy export is retired. "
        f"The app no longer uses {db_path.name} or {out_path.name}; "
        "use standard_lectionary_complete.csv and memorial_feasts.csv instead."
    )
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
