from __future__ import annotations

from dataclasses import asdict, dataclass
from enum import Enum
from typing import Any


class ReuseStatus(str, Enum):
    OPEN = "open"
    PUBLIC_DOMAIN = "public_domain"
    LICENSED = "licensed"
    COMPARISON_ONLY = "comparison_only"
    UNKNOWN = "unknown"


@dataclass(frozen=True)
class SourceRecord:
    source_id: str
    source_name: str
    source_edition: str
    source_territory: str
    source_url: str
    source_license: str
    reuse_status: ReuseStatus
    coverage: str
    access_method: str
    notes: str

    @classmethod
    def from_dict(cls, raw: dict[str, Any]) -> "SourceRecord":
        return cls(
            source_id=str(raw["source_id"]),
            source_name=str(raw["source_name"]),
            source_edition=str(raw.get("source_edition", "")),
            source_territory=str(raw.get("source_territory", "")),
            source_url=str(raw["source_url"]),
            source_license=str(raw.get("source_license", "unknown")),
            reuse_status=ReuseStatus(str(raw["reuse_status"])),
            coverage=str(raw.get("coverage", "")),
            access_method=str(raw.get("access_method", "")),
            notes=str(raw.get("notes", "")),
        )


@dataclass(frozen=True)
class PsalmSourceRow:
    usage_id: str
    celebration_id: str
    celebration_title: str
    date_rule: str
    season: str
    week: str
    weekday: str
    sunday_cycle: str
    weekday_cycle: str
    lectionary_number: str
    territory: str
    reading_set_kind: str
    reading_set_priority: int
    biblical_book: str
    psalm_number_hebrew: str
    psalm_number_vulgate: str
    reference_raw: str
    reference_normalized: str
    stanza_selection_normalized: str
    response_verse_normalized: str
    source_id: str
    source_name: str
    source_edition: str
    source_territory: str
    source_url: str
    retrieved_at: str
    source_license: str
    reuse_status: str
    response_raw: str
    response_normalized: str
    stanzas_raw: str
    stanzas_normalized: str
    raw_sha256: str
    normalized_sha256: str
    token_count: int
    comparison_target: str = ""
    reference_match_score: str = ""
    response_match_score: str = ""
    stanza_match_score: str = ""
    text_match_score: str = ""
    difference_class: str = ""
    review_status: str = "unreviewed"
    notes: str = ""
    display_eligible: bool = False
    display_priority: int = 0
    eligibility_basis: str = ""

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)
