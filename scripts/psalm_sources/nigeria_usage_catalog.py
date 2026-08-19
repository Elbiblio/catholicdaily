from __future__ import annotations

from dataclasses import asdict, dataclass
import csv
from pathlib import Path
from typing import Iterable, Sequence

from .models import PsalmSourceRow
from .nigeria_365 import canonicalize_nigeria_reference
from .normalize import normalize_reference


CATALOG_FIELDS = (
    "usage_id",
    "territory",
    "kind",
    "celebration_id",
    "mass_form",
    "season",
    "week",
    "weekday",
    "special_day",
    "sunday_cycle",
    "weekday_cycle",
    "reference_normalized",
    "reference_display",
    "response_text",
    "source_date",
    "source_selection_id",
    "source_edition",
    "choice_priority",
    "review_status",
)

ASSIGNMENT_FIELDS = (
    "source_selection_id",
    "territory",
    "kind",
    "celebration_id",
    "mass_form",
    "season",
    "week",
    "weekday",
    "special_day",
    "sunday_cycle",
    "weekday_cycle",
    "choice_priority",
    "review_status",
    "exclusion_reason",
)


@dataclass(frozen=True)
class NigeriaPsalmUsageAssignment:
    source_selection_id: str
    territory: str
    kind: str
    celebration_id: str = ""
    mass_form: str = ""
    season: str = ""
    week: str = ""
    weekday: str = ""
    special_day: str = ""
    sunday_cycle: str = ""
    weekday_cycle: str = ""
    choice_priority: int = 1
    review_status: str = "unreviewed"
    exclusion_reason: str = ""


@dataclass(frozen=True)
class NigeriaPsalmUsageRow:
    usage_id: str
    territory: str
    kind: str
    celebration_id: str
    mass_form: str
    season: str
    week: str
    weekday: str
    special_day: str
    sunday_cycle: str
    weekday_cycle: str
    reference_normalized: str
    reference_display: str
    response_text: str
    source_date: str
    source_selection_id: str
    source_edition: str
    choice_priority: int
    review_status: str

    @property
    def stable_key(self) -> str:
        if self.kind == "temporal":
            return "|".join(
                (
                    self.territory,
                    self.kind,
                    self.season,
                    self.week,
                    self.weekday,
                    self.sunday_cycle,
                    self.weekday_cycle,
                )
            )
        if self.kind == "celebration":
            return "|".join(
                (
                    self.territory,
                    self.kind,
                    self.celebration_id,
                    self.mass_form,
                    self.sunday_cycle,
                    self.weekday_cycle,
                )
            )
        return "|".join(
            (
                self.territory,
                self.kind,
                self.special_day,
                self.mass_form,
                self.sunday_cycle,
                self.weekday_cycle,
            )
        )

    def to_dict(self) -> dict[str, object]:
        values = asdict(self)
        return {field: values[field] for field in CATALOG_FIELDS}


def _validate_assignment(assignment: NigeriaPsalmUsageAssignment) -> None:
    if not assignment.source_selection_id.strip():
        raise ValueError("assignment has no source selection id")
    if not assignment.territory.strip():
        raise ValueError(
            f"assignment has no territory: {assignment.source_selection_id}"
        )
    if assignment.kind == "excluded":
        if assignment.review_status != "verified":
            raise ValueError(
                f"excluded assignment is not verified: {assignment.source_selection_id}"
            )
        if not assignment.exclusion_reason.strip():
            raise ValueError(
                f"excluded assignment has no reason: {assignment.source_selection_id}"
            )
        return
    if assignment.kind == "temporal":
        missing = [
            name
            for name, value in (
                ("season", assignment.season),
                ("week", assignment.week),
                ("weekday", assignment.weekday),
            )
            if not value.strip()
        ]
        if missing:
            raise ValueError(
                f"temporal assignment missing {', '.join(missing)}: "
                f"{assignment.source_selection_id}"
            )
        if not (
            assignment.sunday_cycle.strip()
            or assignment.weekday_cycle.strip()
        ):
            raise ValueError(
                f"temporal assignment missing applicable cycle: "
                f"{assignment.source_selection_id}"
            )
        return
    if assignment.kind == "celebration":
        if not assignment.celebration_id.strip():
            raise ValueError(
                f"celebration assignment missing celebration id: "
                f"{assignment.source_selection_id}"
            )
        if not assignment.mass_form.strip():
            raise ValueError(
                f"celebration assignment missing mass form: "
                f"{assignment.source_selection_id}"
            )
        return
    if assignment.kind in {"special-period", "special_period"}:
        if not assignment.special_day.strip():
            raise ValueError(
                f"special-period assignment missing special day: "
                f"{assignment.source_selection_id}"
            )
        return
    raise ValueError(
        f"unknown assignment kind {assignment.kind!r}: "
        f"{assignment.source_selection_id}"
    )


def validate_nigeria_usage_catalog(
    rows: Iterable[NigeriaPsalmUsageRow],
) -> tuple[NigeriaPsalmUsageRow, ...]:
    result = tuple(rows)
    seen_usage_ids: set[str] = set()
    seen_source_ids: set[str] = set()
    seen_choices: set[tuple[str, int]] = set()
    for row in result:
        if row.review_status != "verified":
            raise ValueError(f"usage is not verified: {row.usage_id}")
        if not row.reference_normalized.strip():
            raise ValueError(f"usage has no reference: {row.usage_id}")
        if not row.response_text.strip():
            raise ValueError(f"usage has no response: {row.usage_id}")
        if row.usage_id in seen_usage_ids:
            raise ValueError(f"duplicate usage id: {row.usage_id}")
        seen_usage_ids.add(row.usage_id)
        if row.source_selection_id in seen_source_ids:
            raise ValueError(
                f"duplicate source selection: {row.source_selection_id}"
            )
        seen_source_ids.add(row.source_selection_id)
        choice_key = (row.stable_key, row.choice_priority)
        if choice_key in seen_choices:
            raise ValueError(
                f"ambiguous stable key and priority: {row.stable_key} "
                f"#{row.choice_priority}"
            )
        seen_choices.add(choice_key)
    return tuple(
        sorted(
            result,
            key=lambda row: (
                row.stable_key,
                row.choice_priority,
                row.usage_id,
            ),
        )
    )


def build_nigeria_usage_catalog(
    source_rows: Sequence[PsalmSourceRow],
    assignments: Sequence[NigeriaPsalmUsageAssignment],
    *,
    validate: bool = True,
) -> tuple[NigeriaPsalmUsageRow, ...]:
    source_by_id = {row.usage_id: row for row in source_rows}
    if len(source_by_id) != len(source_rows):
        raise ValueError("duplicate source selection id")

    assignment_by_id: dict[str, NigeriaPsalmUsageAssignment] = {}
    for assignment in assignments:
        _validate_assignment(assignment)
        if assignment.source_selection_id in assignment_by_id:
            raise ValueError(
                f"duplicate assignment: {assignment.source_selection_id}"
            )
        if assignment.source_selection_id not in source_by_id:
            raise ValueError(
                f"assignment has no source row: {assignment.source_selection_id}"
            )
        assignment_by_id[assignment.source_selection_id] = assignment

    missing = sorted(set(source_by_id) - set(assignment_by_id))
    if missing:
        raise ValueError(f"missing assignment: {', '.join(missing)}")

    rows: list[NigeriaPsalmUsageRow] = []
    for source in source_rows:
        assignment = assignment_by_id[source.usage_id]
        if assignment.kind == "excluded":
            continue
        kind = assignment.kind.replace("_", "-")
        display_reference = canonicalize_nigeria_reference(
            source.date_rule,
            source.reference_normalized,
        )
        rows.append(
            NigeriaPsalmUsageRow(
                usage_id=(
                    f"{assignment.territory.lower()}:"
                    f"{kind}:{source.usage_id}"
                ),
                territory=assignment.territory,
                kind=kind,
                celebration_id=assignment.celebration_id,
                mass_form=assignment.mass_form,
                season=assignment.season,
                week=assignment.week,
                weekday=assignment.weekday,
                special_day=assignment.special_day,
                sunday_cycle=assignment.sunday_cycle,
                weekday_cycle=assignment.weekday_cycle,
                reference_normalized=normalize_reference(display_reference),
                reference_display=display_reference,
                response_text=source.response_raw,
                source_date=source.date_rule,
                source_selection_id=source.usage_id,
                source_edition=source.source_edition,
                choice_priority=assignment.choice_priority,
                review_status=assignment.review_status,
            )
        )
    if validate:
        return validate_nigeria_usage_catalog(rows)
    return tuple(rows)


def write_nigeria_usage_assignments(
    path: Path,
    assignments: Iterable[NigeriaPsalmUsageAssignment],
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=ASSIGNMENT_FIELDS)
        writer.writeheader()
        for assignment in sorted(
            assignments,
            key=lambda item: item.source_selection_id,
        ):
            writer.writerow(asdict(assignment))


def load_nigeria_usage_assignments(
    path: Path,
) -> tuple[NigeriaPsalmUsageAssignment, ...]:
    with path.open(encoding="utf-8-sig", newline="") as handle:
        return tuple(
            NigeriaPsalmUsageAssignment(
                source_selection_id=row["source_selection_id"],
                territory=row["territory"],
                kind=row["kind"],
                celebration_id=row["celebration_id"],
                mass_form=row["mass_form"],
                season=row["season"],
                week=row["week"],
                weekday=row["weekday"],
                special_day=row["special_day"],
                sunday_cycle=row["sunday_cycle"],
                weekday_cycle=row["weekday_cycle"],
                choice_priority=int(row["choice_priority"]),
                review_status=row["review_status"],
                exclusion_reason=row["exclusion_reason"],
            )
            for row in csv.DictReader(handle)
        )


def write_nigeria_usage_catalog(
    path: Path,
    rows: Iterable[NigeriaPsalmUsageRow],
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=CATALOG_FIELDS)
        writer.writeheader()
        for row in validate_nigeria_usage_catalog(rows):
            writer.writerow(row.to_dict())
