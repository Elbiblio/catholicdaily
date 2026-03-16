#!/usr/bin/env python3
"""Test script for tiered psalm resolver."""
from __future__ import annotations

import datetime as dt
import sqlite3
import sys
from pathlib import Path

from psalm_source_resolver import (
    TieredPsalmResolver,
    sunday_cycle_for_date,
    weekday_cycle_for_date,
)


def main() -> int:
    print(
        "This legacy psalm resolver script is retired. "
        "Validate psalm resolution against the CSV catalogs and LectionaryPsalmCatalogService instead."
    )
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
