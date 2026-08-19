from __future__ import annotations

from dataclasses import dataclass, replace
import csv
from pathlib import Path
import re
from typing import Iterable

from .normalize import normalize_reference, normalize_words


@dataclass(frozen=True)
class LiturgicalUsageTarget:
    territory: str
    kind: str
    reference_normalized: str
    response_text: str
    choice_priority: int
    celebration_id: str = ""
    mass_form: str = ""
    season: str = ""
    week: str = ""
    weekday: str = ""
    special_day: str = ""
    sunday_cycle: str = ""
    weekday_cycle: str = ""
    lectionary_number: str = ""
    source_catalog: str = ""
    date_rule: str = ""

    @property
    def stable_key(self) -> str:
        if self.kind == "temporal":
            values = (
                self.territory,
                self.kind,
                self.season,
                self.week,
                self.weekday,
                self.sunday_cycle,
                self.weekday_cycle,
            )
        elif self.kind == "celebration":
            values = (
                self.territory,
                self.kind,
                self.celebration_id,
                self.mass_form,
                self.sunday_cycle,
                self.weekday_cycle,
            )
        else:
            values = (
                self.territory,
                self.kind,
                self.special_day,
                self.mass_form,
                self.sunday_cycle,
                self.weekday_cycle,
            )
        return "|".join(values)


_PROPER_TITLES: tuple[tuple[str, str, str], ...] = (
    ("IMMACULATE CONCEPTION", "immaculate_conception_of_blessed_virgin_mary", "day"),
    ("CHRISTMAS (VIGIL", "nativity_of_the_lord", "vigil"),
    ("CHRISTMAS (MASS AT MIDNIGHT", "nativity_of_the_lord", "midnight"),
    ("CHRISTMAS (MASS AT DAWN", "nativity_of_the_lord", "dawn"),
    ("CHRISTMAS (MASS DURING THE DAY", "nativity_of_the_lord", "day"),
    ("EPIPHANY OF THE LORD", "epiphany_of_the_lord", "day"),
    ("THE BAPTISM OF THE LORD", "baptism_of_the_lord", "day"),
    ("HOLY FAMILY", "holy_family", "day"),
    ("MARY, MOTHER OF GOD", "mary_mother_of_god", "day"),
    ("PRESENTATION OF THE LORD", "presentation_of_the_lord", "day"),
    ("THE ASCENSION OF THE LORD", "ascension_of_the_lord", "day"),
    ("PENTECOST SUNDAY (VIGIL", "pentecost_sunday", "vigil"),
    ("PENTECOST SUNDAY", "pentecost_sunday", "day"),
    ("HOLY TRINITY", "most_holy_trinity", "day"),
    ("BODY AND BLOOD OF CHRIST", "body_and_blood_of_christ", "day"),
    ("CORPUS CHRISTI", "body_and_blood_of_christ", "day"),
    ("SACRED HEART OF JESUS", "most_sacred_heart_of_jesus", "day"),
    ("NATIVITY OF JOHN THE BAPTIST (VIGIL", "nativity_of_saint_john_the_baptist", "vigil"),
    ("NATIVITY OF JOHN THE BAPTIST", "nativity_of_saint_john_the_baptist", "day"),
    ("SS. PETER AND PAUL, APOSTLES (VIGIL", "saints_peter_and_paul_apostles", "vigil"),
    ("SS. PETER AND PAUL, APOSTLES", "saints_peter_and_paul_apostles", "day"),
    ("SS. PETER AND PAUL (DAY", "saints_peter_and_paul_apostles", "day"),
    ("TRANSFIGURATION OF THE LORD", "transfiguration_of_the_lord", "day"),
    ("ASSUMPTION OF THE BLESSED VIRGIN MARY (VIGIL", "the_assumption_of_the_blessed_virgin_mary", "vigil"),
    ("ASSUMPTION OF THE BLESSED VIRGIN MARY", "the_assumption_of_the_blessed_virgin_mary", "day"),
    ("EXALTATION OF THE HOLY CROSS", "exaltation_of_holy_cross", "day"),
    ("ALL SAINTS", "all_saints", "day"),
    ("ALL SOULS", "all_souls", "day"),
    ("DEDICATION OF ST. JOHN LATERAN", "dedication_of_lateran_basilica", "day"),
    ("CHRIST THE KING", "christ_the_king", "day"),
)


def _read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def _slug(value: str) -> str:
    return re.sub(r"-+", "-", re.sub(r"[^a-z0-9]+", "-", value.lower())).strip("-")


def _response(value: str) -> str:
    text = value.strip()
    text = re.sub(r"^\s*R\s*(?:/\.|\.)\s*", "", text, flags=re.I)
    text = re.sub(r"^\s*\([^)]+\)\s*", "", text)
    text = re.sub(r"\s*\(R\.[^)]+\)\s*$", "", text, flags=re.I)
    text = re.sub(r"\s*\+{2,}\s*$", "", text)
    return " ".join(text.split()).strip()


def normalize_selection_reference(value: str) -> str:
    without_response_verse = re.sub(
        r"\s*\(\s*R\.?\s*[^)]*\)\s*",
        "",
        value,
        flags=re.I,
    )
    without_response_verse = re.sub(
        r"\s*\([^)]*\)\s*$", "", without_response_verse
    )
    normalized = normalize_reference(without_response_verse).rstrip(",")
    corrections = {
        "ps23:13a,3b4,5,6": "ps23:1-3a,3b-4,5,6",
        "ps114:1-2,3-4,5-6,8-9": "ps116:1-2,3-4,5-6,8-9",
        "ps122:1-2,3-4,7-8,9-10": "ps122:1-2,3-4,4-5,6-7,8-9",
        "ps138:12a,1-2a,2bc-3,7c-8": "ps138:1-2a,2bc-3,7c-8",
        "ps27:1,2,3,13-15": "ps27:1,2,3,13-14",
        "ps31:1-25": "ps31:2,6,12-13,15-16,17,25",
        "ps42:1-2,43,3,4": "ps42:2-3,43:3,4",
        "ps42:1-2,3,43,3,4": "ps42:2,3,43:3,4",
    }
    return corrections.get(normalized, normalized)


def _cycles(value: str, *, sunday: bool) -> tuple[str, ...]:
    cleaned = value.strip().upper()
    if not cleaned:
        return ("",)
    if sunday and cleaned in {"ABC", "A/B/C"}:
        return ("A", "B", "C")
    if not sunday and cleaned in {"I/II", "I,II"}:
        return ("I", "II")
    return tuple(part for part in re.split(r"[/,]", cleaned) if part)


def _proper(source_title: str) -> tuple[str, str] | None:
    title = source_title.upper().replace("—", "-")
    for prefix, celebration_id, mass_form in _PROPER_TITLES:
        if title.startswith(prefix):
            return celebration_id, mass_form
    return None


def _standard_context(row: dict[str, str]) -> tuple[str, dict[str, str]]:
    title = row["source_title"].strip()
    upper_title = title.upper()
    if upper_title.startswith("EASTER VIGIL"):
        return "special-period", {"special_day": "easter-vigil"}
    if upper_title.startswith("SECOND SUNDAY AFTER CHRISTMAS"):
        return "special-period", {
            "special_day": "second-sunday-after-christmas"
        }
    proper = _proper(title)
    if proper is not None:
        return "celebration", {
            "celebration_id": proper[0],
            "mass_form": proper[1],
        }

    season = _slug(row["season"])
    week = row["week"].strip()
    weekday = _slug(row["day"])
    if weekday == "ash-wednesday":
        return "special-period", {"special_day": "ash-wednesday"}
    if season == "holy-week":
        return "special-period", {"special_day": f"holy-week-{weekday}"}
    if season == "easter" and week.lower() == "vigil":
        return "special-period", {"special_day": "easter-vigil"}
    if season == "easter" and week.lower() == "octave":
        return "special-period", {"special_day": f"easter-octave-{weekday}"}
    if season == "christmas" and week.lower() == "octave":
        special = weekday.replace("january-", "christmas-january-")
        if special == weekday:
            special = f"christmas-octave-{weekday}"
        return "special-period", {"special_day": special}
    if season == "advent" and week.lower() == "dec-17-24":
        return "special-period", {"special_day": f"advent-{weekday}"}
    if season == "advent" and weekday.startswith("december-"):
        return "special-period", {"special_day": f"advent-{weekday}"}
    return "temporal", {
        "season": season,
        "week": week,
        "weekday": weekday,
    }


def _from_standard(root: Path) -> list[LiturgicalUsageTarget]:
    output: list[LiturgicalUsageTarget] = []
    for row in _read_csv(root / "standard_lectionary_complete.csv"):
        if not row["psalm_reference"].strip() or not row["psalm_response"].strip():
            continue
        source_title = row["source_title"].strip().upper()
        # This legacy row collapses the Vigil canticles and pairs Psalm 118
        # with Psalm 16's response. Reviewed assignments supply the real set.
        if source_title.startswith("EASTER VIGIL"):
            continue
        # Nigeria transfers Epiphany to Sunday, so this slot is not used.
        if source_title.startswith("SECOND SUNDAY AFTER CHRISTMAS"):
            continue
        # Keep the fixed January 2-7 rows, not undated legacy weekday clones.
        if (
            row["season"].strip().lower() == "christmas"
            and row["week"].strip().lower() == "octave"
            and not row["day"].strip().lower().startswith("january ")
        ):
            continue
        kind, dimensions = _standard_context(row)
        sunday_values = _cycles(row["sunday_cycle"], sunday=True)
        weekday_values = _cycles(row["weekday_cycle"], sunday=False)
        for sunday_cycle in sunday_values:
            for weekday_cycle in weekday_values:
                output.append(
                    LiturgicalUsageTarget(
                        territory="NG",
                        kind=kind,
                        reference_normalized=normalize_selection_reference(row["psalm_reference"]),
                        response_text=_response(row["psalm_response"]),
                        choice_priority=1,
                        sunday_cycle=sunday_cycle,
                        weekday_cycle=weekday_cycle,
                        lectionary_number=row["lectionary_number"].strip(),
                        source_catalog="standard_lectionary_complete.csv",
                        **dimensions,
                    )
                )
    return output


def _from_memorials(root: Path) -> list[LiturgicalUsageTarget]:
    output: list[LiturgicalUsageTarget] = []
    commons = _common_psalm_choices(root)
    for row in _read_csv(root / "memorial_feasts.csv"):
        if not row["id"].strip() or row["id"].strip() == "...":
            continue
        reference = row["psalmReference"].strip()
        response = _response(row["psalmResponse"])
        if reference and response:
            choices = ((normalize_selection_reference(reference), response),)
        else:
            common_ids = _common_ids_for_memorial(row)
            choices = tuple(
                choice
                for common_id in common_ids
                for choice in commons.get(common_id, ())
            )
        if not choices:
            continue
        output.extend(
            LiturgicalUsageTarget(
                territory="NG",
                kind="celebration",
                celebration_id=row["id"].strip(),
                mass_form="day",
                reference_normalized=choice[0],
                response_text=choice[1],
                choice_priority=index,
                source_catalog="memorial_feasts.csv",
            )
            for index, choice in enumerate(choices, start=1)
        )
    for common_id, choices in commons.items():
        output.extend(
            LiturgicalUsageTarget(
                territory="NG",
                kind="celebration",
                celebration_id=f"common_of_{common_id}",
                mass_form="day",
                reference_normalized=choice[0],
                response_text=choice[1],
                choice_priority=index,
                source_catalog="weekday_b_full.txt:commons",
            )
            for index, choice in enumerate(choices, start=1)
        )
    return output


_COMMON_TYPE_MAP: dict[str, tuple[str, ...]] = {
    "Abbots": ("holy_men_and_women",),
    "Bishops": ("pastors",),
    "DoctorsOfTheChurch": ("doctors",),
    "Educators": ("holy_men_and_women",),
    "MercyWorkers": ("holy_men_and_women",),
    "Missionaries": ("pastors", "holy_men_and_women"),
    "Monks": ("holy_men_and_women",),
    "Martyrs": ("martyrs",),
    "Pastors": ("pastors",),
    "Popes": ("pastors",),
    "Religious": ("holy_men_and_women",),
    "Saints": ("holy_men_and_women",),
    "VirginMartyrs": ("martyrs", "virgins"),
    "Virgins": ("virgins",),
}


def _common_ids_for_memorial(row: dict[str, str]) -> tuple[str, ...]:
    if row["id"].strip() == "dedication_of_basilicas_of_peter_and_paul":
        return ("dedication",)
    return _COMMON_TYPE_MAP.get(row["commonType"].strip(), ())


def _common_psalm_choices(
    root: Path,
) -> dict[str, tuple[tuple[str, str], ...]]:
    lines = (root / "scripts/weekday_b_full.txt").read_text(
        encoding="utf-8"
    ).splitlines()
    exact_headers = {
        "COMMON OF THE DEDICATION": "dedication",
        "COMMON OF MARTYRS": "martyrs",
        "COMMON OF PASTORS": "pastors",
        "COMMON OF DOCTORS": "doctors",
        "COMMON OF VIRGINS": "virgins",
        "COMMON OF HOLY MEN AND WOMEN": "holy_men_and_women",
    }
    current = ""
    pending_bvm = False
    found: dict[str, dict[tuple[str, str], tuple[str, str]]] = {}
    for index, raw in enumerate(lines):
        line = " ".join(raw.strip().split())
        if line in exact_headers:
            current = exact_headers[line]
            pending_bvm = False
            continue
        if line == "COMMON OF":
            pending_bvm = True
            continue
        if pending_bvm and line == "THE BLESSED VIRGIN MARY":
            current = "blessed_virgin_mary"
            pending_bvm = False
            continue
        if not current:
            continue
        match = re.match(
            r"^RESPONSORIAL PSALM\s+(.+?)(?:\s+\(R\.[^)]+\))?$",
            line,
            flags=re.I,
        )
        if match is None:
            continue
        reference = normalize_selection_reference(match.group(1))
        response = ""
        for candidate_raw in lines[index + 1 : index + 18]:
            candidate = " ".join(candidate_raw.strip().split())
            if not candidate:
                continue
            if candidate.upper().startswith("RESPONSORIAL PSALM"):
                break
            if re.match(r"^\d+\s", candidate):
                continue
            if candidate.startswith("R.") or candidate.startswith("R/"):
                response = _response(candidate)
                break
        if not response:
            continue
        key = (reference, normalize_words(response))
        found.setdefault(current, {}).setdefault(key, (reference, response))
    return {
        common_id: tuple(
            choices[key]
            for key in sorted(choices)
        )
        for common_id, choices in found.items()
    }


def _usage_dimensions(row: dict[str, str]) -> dict[str, str]:
    kind = row["kind"].replace("_", "-")
    values: dict[str, str] = {
        "celebration_id": row.get("celebration_id", "").strip(),
        "mass_form": row.get("mass_form", "").strip(),
        "season": row.get("season", "").strip(),
        "week": row.get("week", "").strip(),
        "weekday": row.get("weekday", "").strip(),
        "special_day": row.get("special_day", "").strip(),
        "sunday_cycle": row.get("sunday_cycle", "").strip(),
        "weekday_cycle": row.get("weekday_cycle", "").strip(),
    }
    values["kind"] = kind
    return values


def _from_current_assignments(root: Path) -> list[LiturgicalUsageTarget]:
    output: list[LiturgicalUsageTarget] = []
    assignment_path = (
        root / "verification/psalm_sources/nigeria_psalm_usage_assignments.csv"
    )
    pack_path = root / "assets/data/psalm_editions/nigeria_365.csv"
    if not assignment_path.exists() or not pack_path.exists():
        return output
    source_by_id = {
        row["selection_id"]: row
        for row in _read_csv(pack_path)
        if row["source_edition"] != "verified Nigerian fragments"
    }
    for row in _read_csv(assignment_path):
        if row["kind"] == "excluded" or row["review_status"] != "verified":
            continue
        source = source_by_id.get(row["source_selection_id"])
        if source is None:
            continue
        dimensions = _usage_dimensions(row)
        kind = dimensions.pop("kind")
        output.append(
            LiturgicalUsageTarget(
                territory=row["territory"].strip().upper() or "NG",
                kind=kind,
                reference_normalized=normalize_selection_reference(
                    source["reference_normalized"]
                ),
                response_text=_response(source["response_text"]),
                choice_priority=int(row["choice_priority"]),
                source_catalog="nigeria_psalm_usage_assignments.csv",
                **dimensions,
            )
        )
    return output


def _from_history(root: Path) -> list[LiturgicalUsageTarget]:
    output: list[LiturgicalUsageTarget] = []
    path = root / "verification/psalm_sources/nigeria_2024_2025_usage_assignments.csv"
    if not path.exists():
        return output
    for row in _read_csv(path):
        if row["reconciliation_status"] == "conflict_review_required":
            continue
        dimensions = _usage_dimensions(row)
        kind = dimensions.pop("kind")
        output.append(
            LiturgicalUsageTarget(
                territory="NG",
                kind=kind,
                reference_normalized=normalize_selection_reference(row["selected_reference"]),
                response_text=_response(row["selected_response"]),
                choice_priority=1,
                source_catalog="nigeria_2024_2025_usage_assignments.csv",
                **dimensions,
            )
        )
    return output


def _deduplicate_and_prioritize(
    rows: Iterable[LiturgicalUsageTarget],
) -> list[LiturgicalUsageTarget]:
    grouped: dict[str, dict[tuple[str, str], LiturgicalUsageTarget]] = {}
    source_order = {
        "nigeria_psalm_usage_assignments.csv": 0,
        "nigeria_2024_2025_usage_assignments.csv": 1,
        "standard_lectionary_complete.csv": 2,
        "memorial_feasts.csv": 3,
    }
    for row in rows:
        choice = (
            row.reference_normalized,
            normalize_words(row.response_text),
        )
        choices = grouped.setdefault(row.stable_key, {})
        previous = choices.get(choice)
        if previous is None or source_order.get(row.source_catalog, 99) < source_order.get(previous.source_catalog, 99):
            choices[choice] = row

    output: list[LiturgicalUsageTarget] = []
    for stable_key in sorted(grouped):
        choices = sorted(
            grouped[stable_key].values(),
            key=lambda row: (
                source_order.get(row.source_catalog, 99),
                row.choice_priority,
                row.reference_normalized,
                normalize_words(row.response_text),
            ),
        )
        output.extend(
            replace(row, choice_priority=index)
            for index, row in enumerate(choices, start=1)
        )
    return output


def build_liturgical_usage_universe(root: Path) -> list[LiturgicalUsageTarget]:
    return _deduplicate_and_prioritize(
        (
            *_from_standard(root),
            *_from_memorials(root),
            *_from_current_assignments(root),
            *_from_history(root),
        )
    )


def validate_liturgical_usage_universe(
    rows: Iterable[LiturgicalUsageTarget],
) -> tuple[LiturgicalUsageTarget, ...]:
    result = tuple(rows)
    seen: set[tuple[str, int]] = set()
    for row in result:
        if row.date_rule:
            raise ValueError(f"civil date leaked into stable usage: {row.stable_key}")
        if not row.reference_normalized or not row.response_text:
            raise ValueError(f"incomplete usage choice: {row.stable_key}")
        if row.kind not in {"temporal", "celebration", "special-period"}:
            raise ValueError(f"unknown usage kind: {row.kind}")
        key = (row.stable_key, row.choice_priority)
        if key in seen:
            raise ValueError(f"duplicate usage choice: {key}")
        seen.add(key)
    return tuple(sorted(result, key=lambda row: (row.stable_key, row.choice_priority)))
