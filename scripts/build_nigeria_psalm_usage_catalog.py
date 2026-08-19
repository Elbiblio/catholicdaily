from __future__ import annotations

import argparse
import csv
import hashlib
import io
from pathlib import Path
import tempfile

if __package__:
    from scripts.build_complete_nigeria_psalm_coverage import (
        build_coverage_rows,
        load_nigeria_pack,
    )
    from scripts.psalm_sources.liturgical_usage_universe import (
        build_liturgical_usage_universe,
        validate_liturgical_usage_universe,
    )
    from scripts.psalm_sources.nigeria_365 import canonicalize_nigeria_reference
    from scripts.psalm_sources.nigeria_usage_catalog import CATALOG_FIELDS
else:
    from build_complete_nigeria_psalm_coverage import (
        build_coverage_rows,
        load_nigeria_pack,
    )
    from psalm_sources.liturgical_usage_universe import (
        build_liturgical_usage_universe,
        validate_liturgical_usage_universe,
    )
    from psalm_sources.nigeria_365 import canonicalize_nigeria_reference
    from psalm_sources.nigeria_usage_catalog import CATALOG_FIELDS


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "assets/data/nigeria_psalm_usages.csv"
NIGERIA_PACK = ROOT / "assets/data/psalm_editions/nigeria_365.csv"


def _usage_id(row: dict[str, object]) -> str:
    identity = "|".join(
        (
            str(row["stable_usage_key"]),
            str(row["choice_priority"]),
            str(row["reference_normalized"]),
            str(row["response_text"]),
        )
    )
    return "ng:usage:" + hashlib.sha1(identity.encode("utf-8")).hexdigest()[:20]


def _source_selection_id(row: dict[str, object]) -> str:
    for field in ("nigeria_selection_id", "rsvce_selection_id"):
        value = str(row[field]).strip()
        if value:
            return value
    gallery_url = str(row["gallery_source_url"]).strip()
    if gallery_url:
        return "gallery:" + hashlib.sha1(gallery_url.encode("utf-8")).hexdigest()[:16]
    return "missing:" + hashlib.sha1(
        (str(row["reference_normalized"]) + "|" + str(row["response_text"])).encode(
            "utf-8"
        )
    ).hexdigest()[:16]


def build_runtime_rows() -> list[dict[str, object]]:
    universe = validate_liturgical_usage_universe(
        build_liturgical_usage_universe(ROOT)
    )
    nigeria = load_nigeria_pack(NIGERIA_PACK)
    coverage = build_coverage_rows(universe=universe, nigeria=nigeria)
    output: list[dict[str, object]] = []
    for target, resolution in zip(universe, coverage, strict=True):
        status = str(resolution["resolution_status"])
        review_status = {
            "exact_nigeria": "verified",
            "reconstructed_nigeria": "verified",
            "fallback": "verified-fallback",
            "missing": "missing-text",
        }[status]
        display_edition = str(resolution["display_edition"]).strip()
        output.append(
            {
                "usage_id": _usage_id(resolution),
                "territory": target.territory,
                "kind": target.kind,
                "celebration_id": target.celebration_id,
                "mass_form": target.mass_form,
                "season": target.season,
                "week": target.week,
                "weekday": target.weekday,
                "special_day": target.special_day,
                "sunday_cycle": target.sunday_cycle,
                "weekday_cycle": target.weekday_cycle,
                "reference_normalized": target.reference_normalized,
                "reference_display": canonicalize_nigeria_reference(
                    "", target.reference_normalized
                ),
                "response_text": target.response_text,
                "source_date": str(resolution["nigeria_source_date"]),
                "source_selection_id": _source_selection_id(resolution),
                "source_edition": display_edition
                or "No installed full-text edition",
                "choice_priority": target.choice_priority,
                "review_status": review_status,
            }
        )
    return output


def _csv_text(rows: list[dict[str, object]]) -> str:
    output = io.StringIO(newline="")
    writer = csv.DictWriter(output, fieldnames=CATALOG_FIELDS)
    writer.writeheader()
    writer.writerows(rows)
    return output.getvalue()


def _read_exact(path: Path) -> str:
    with path.open(encoding="utf-8", newline="") as handle:
        return handle.read()


def _atomic_write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        mode="w",
        encoding="utf-8",
        newline="",
        delete=False,
        dir=path.parent,
    ) as handle:
        handle.write(text)
        temporary = Path(handle.name)
    temporary.replace(path)


def generate(path: Path = DEFAULT_OUTPUT, *, check: bool = False) -> int:
    rows = build_runtime_rows()
    text = _csv_text(rows)
    if check:
        if not path.exists() or _read_exact(path) != text:
            raise SystemExit(f"stale Nigeria psalm usage catalog: {path}")
    else:
        _atomic_write(path, text)
    return len(rows)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    count = generate(args.output, check=args.check)
    print(f"Nigeria psalm usages: {count} ordered liturgical choices.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
