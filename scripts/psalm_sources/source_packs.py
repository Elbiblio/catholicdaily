from __future__ import annotations

from dataclasses import dataclass
import hashlib
import json
from pathlib import Path
from typing import Iterable, Mapping, Sequence

from .edition_corpus import write_csv_rows
from .models import PsalmEditionText, SourceRecord
from .normalize import normalize_words


PACK_FIELDS = (
    "edition_id",
    "selection_id",
    "territory",
    "celebration_id",
    "date_rule",
    "reading_set_kind",
    "sunday_cycle",
    "weekday_cycle",
    "lectionary_number",
    "reference_normalized",
    "response_text",
    "stanzas_text",
    "source_url",
    "source_edition",
    "raw_sha256",
    "normalized_sha256",
    "display_priority",
)


PACK_KEY = (
    "edition_id",
    "selection_id",
    "territory",
    "celebration_id",
    "reading_set_kind",
    "sunday_cycle",
    "weekday_cycle",
)


@dataclass(frozen=True)
class RuntimePsalmPackRow:
    edition_id: str
    selection_id: str
    territory: str
    celebration_id: str
    date_rule: str
    reading_set_kind: str
    sunday_cycle: str
    weekday_cycle: str
    lectionary_number: str
    reference_normalized: str
    response_text: str
    stanzas_text: str
    source_url: str
    source_edition: str
    display_priority: int

    @property
    def raw_sha256(self) -> str:
        value = f"{self.response_text.strip()}\n\n{self.stanzas_text.strip()}"
        return hashlib.sha256(value.encode("utf-8")).hexdigest()

    @property
    def normalized_sha256(self) -> str:
        value = normalize_words(f"{self.response_text} {self.stanzas_text}")
        return hashlib.sha256(value.encode("utf-8")).hexdigest()

    def to_dict(self) -> dict[str, object]:
        return {field: getattr(self, field) for field in PACK_FIELDS}


def validate_source_pack(
    rows: Iterable[RuntimePsalmPackRow],
) -> tuple[RuntimePsalmPackRow, ...]:
    seen: dict[tuple[object, ...], RuntimePsalmPackRow] = {}
    for row in rows:
        if not row.stanzas_text.strip():
            raise ValueError(f"missing stanza text: {row.selection_id}")
        if len(row.raw_sha256) != 64 or len(row.normalized_sha256) != 64:
            raise ValueError(f"invalid hashes: {row.selection_id}")
        key = tuple(getattr(row, field) for field in PACK_KEY)
        previous = seen.get(key)
        if previous is not None and previous.raw_sha256 != row.raw_sha256:
            raise ValueError(f"conflicting duplicate: {key}")
        seen[key] = row
    return tuple(seen[key] for key in sorted(seen))


def pack_rows_from_editions(
    rows: Iterable[PsalmEditionText],
) -> dict[str, list[RuntimePsalmPackRow]]:
    packs: dict[str, list[RuntimePsalmPackRow]] = {}
    for row in rows:
        packs.setdefault(row.edition_id, []).append(
            RuntimePsalmPackRow(
                edition_id=row.edition_id,
                selection_id=row.selection_id,
                territory=row.territory,
                celebration_id="",
                date_rule="",
                reading_set_kind="generic",
                sunday_cycle="",
                weekday_cycle="",
                lectionary_number="",
                reference_normalized=row.reference_normalized,
                response_text=row.response_text,
                stanzas_text=row.stanzas_text,
                source_url=row.source_url,
                source_edition=row.source_edition,
                display_priority=100,
            )
        )
    return packs


def _abbreviation(record: SourceRecord) -> str:
    labels = {
        "nigeria_365_firestore": "Nigeria Lectionary",
        "modern_psalter_us": "US Lectionary",
        "local_rsvce": "RSVCE",
        "local_nabre": "NABRE",
        "douay_rheims": "Douay-Rheims",
        "jerusalem_bible": "Jerusalem Bible",
        "esvce": "ESV-CE",
    }
    return labels.get(record.source_id, record.source_edition or record.source_name)


def build_manifest(
    *,
    registry: Sequence[SourceRecord],
    packs: Mapping[str, Sequence[RuntimePsalmPackRow]],
) -> dict[str, dict[str, object]]:
    manifest: dict[str, dict[str, object]] = {}
    for record in registry:
        if not record.pack_id:
            continue
        validated = validate_source_pack(packs.get(record.source_id, ()))
        installed = bool(validated)
        manifest[record.source_id] = {
            "id": record.source_id,
            "displayName": record.source_name,
            "abbreviation": _abbreviation(record),
            "sourceKind": record.source_kind,
            "territories": [
                value.strip()
                for value in record.source_territory.split(",")
                if value.strip()
            ],
            "coverageStatus": (
                record.coverage_status if installed else "unavailable"
            ),
            "packAsset": (
                f"assets/data/psalm_editions/{record.pack_id}.csv"
                if installed
                else ""
            ),
            "installed": installed,
            "downloadable": record.renderability == "downloaded",
            "sourceUrl": record.source_url,
            "fallbackRole": record.fallback_role,
            "selectionCount": len(validated),
        }
    return manifest


def write_runtime_packs(
    output_dir: Path,
    *,
    registry: Sequence[SourceRecord],
    edition_rows: Sequence[PsalmEditionText],
) -> dict[str, dict[str, object]]:
    raw_packs = pack_rows_from_editions(edition_rows)
    packs: dict[str, tuple[RuntimePsalmPackRow, ...]] = {}
    for edition_id, rows in raw_packs.items():
        packs[edition_id] = validate_source_pack(rows)

    for record in registry:
        if not record.pack_id:
            continue
        rows = packs.get(record.source_id, ())
        write_csv_rows(
            output_dir / f"{record.pack_id}.csv",
            (row.to_dict() for row in rows),
            fieldnames=PACK_FIELDS,
        )

    manifest = build_manifest(registry=registry, packs=packs)
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "manifest.json").write_text(
        json.dumps({"schemaVersion": 1, "editions": list(manifest.values())}, indent=2)
        + "\n",
        encoding="utf-8",
    )
    return manifest
