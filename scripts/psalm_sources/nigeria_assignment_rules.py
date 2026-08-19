from __future__ import annotations

import csv
from dataclasses import dataclass
from datetime import date, timedelta
from pathlib import Path
from typing import Iterable

from .models import PsalmSourceRow
from .nigeria_365 import canonicalize_nigeria_reference
from .nigeria_usage_catalog import NigeriaPsalmUsageAssignment
from .nigeria_archive import selection_signature
from .normalize import normalize_reference, normalize_words


_WEEKDAYS = (
    "monday",
    "tuesday",
    "wednesday",
    "thursday",
    "friday",
    "saturday",
    "sunday",
)


@dataclass(frozen=True)
class TemporalContext:
    season: str
    week: str
    weekday: str
    sunday_cycle: str
    weekday_cycle: str
    special_day: str = ""


def easter_sunday(year: int) -> date:
    a = year % 19
    b = year // 100
    c = year % 100
    d = b // 4
    e = b % 4
    f = (b + 8) // 25
    g = (b - f + 1) // 3
    h = (19 * a + b - d - g + 15) % 30
    i = c // 4
    k = c % 4
    ll = (32 + 2 * e + 2 * i - h - k) % 7
    m = (a + 11 * h + 22 * ll) // 451
    month = (h + ll - 7 * m + 114) // 31
    day = ((h + ll - 7 * m + 114) % 31) + 1
    return date(year, month, day)


def advent_start(year: int) -> date:
    christmas = date(year, 12, 25)
    sunday_on_or_after = christmas + timedelta(
        days=(6 - christmas.weekday()) % 7
    )
    return sunday_on_or_after - timedelta(days=28)


def temporal_context(day: date) -> TemporalContext:
    easter = easter_sunday(day.year)
    ash_wednesday = easter - timedelta(days=46)
    pentecost = easter + timedelta(days=49)
    advent = advent_start(day.year)
    christmas = date(day.year, 12, 25)
    epiphany = next(
        date(day.year, 1, value)
        for value in range(2, 9)
        if date(day.year, 1, value).weekday() == 6
    )
    baptism = epiphany + timedelta(
        days=1 if epiphany.day in {7, 8} else 7
    )
    weekday = _WEEKDAYS[day.weekday()]
    liturgical_year = day.year if day < advent_start(day.year) else day.year + 1
    sunday_cycle = ("A", "B", "C")[(liturgical_year - 1) % 3]
    weekday_cycle = "II" if liturgical_year % 2 == 0 else "I"

    special_day = ""
    if day == ash_wednesday:
        special_day = "ash-wednesday"
    elif ash_wednesday < day < ash_wednesday + timedelta(days=4):
        special_day = f"after-ash-wednesday-{weekday}"
    elif day == easter - timedelta(days=7):
        special_day = "palm-sunday"
    elif easter - timedelta(days=6) <= day <= easter - timedelta(days=4):
        special_day = f"holy-week-{weekday}"
    elif day == easter - timedelta(days=3):
        special_day = "holy-thursday"
    elif day == easter - timedelta(days=2):
        special_day = "good-friday"
    elif day == easter - timedelta(days=1):
        special_day = "easter-vigil"
    elif easter < day < easter + timedelta(days=7):
        special_day = f"easter-octave-{weekday}"
    elif day.month == 12 and day.day == 24:
        special_day = "advent-december-24"
    elif day.month == 12 and day.day == 25:
        special_day = "christmas-day"
    elif day.month == 12 and 17 <= day.day <= 24:
        special_day = f"advent-december-{day.day}"
    elif day.month == 12 and 26 <= day.day <= 31:
        special_day = f"christmas-december-{day.day}"
    elif day.month == 1 and 2 <= day.day <= 7:
        special_day = f"christmas-january-{day.day}"
    elif day.month == 1 and day <= baptism:
        special_day = f"after-epiphany-{weekday}"

    if advent <= day < christmas:
        season = "advent"
        week = str(min(4, (day - advent).days // 7 + 1))
    elif christmas <= day or (day.month == 1 and day <= epiphany):
        season = "christmas"
        week = "1"
    elif baptism < day < ash_wednesday:
        ordinary_start = baptism + timedelta(days=1)
        value = (day - ordinary_start).days // 7 + 1
        if day.weekday() == 6:
            value += 1
        season = "ordinary-time"
        week = str(max(1, min(9, value)))
    elif ash_wednesday <= day < easter:
        first_lent_sunday = ash_wednesday + timedelta(days=4)
        season = "lent"
        week = (
            "0"
            if day < first_lent_sunday
            else str(max(1, min(6, (day - first_lent_sunday).days // 7 + 1)))
        )
    elif easter <= day <= pentecost:
        season = "easter"
        week = str(max(1, min(8, (day - easter).days // 7 + 1)))
    elif pentecost < day < advent:
        christ_the_king = advent - timedelta(days=7)
        week_start = day - timedelta(days=(day.weekday() + 1) % 7)
        value = 34 - (christ_the_king - week_start).days // 7
        season = "ordinary-time"
        week = str(max(1, min(34, value)))
    else:
        season = "ordinary-time"
        week = "0"

    return TemporalContext(
        season=season,
        week=week,
        weekday=weekday,
        sunday_cycle=sunday_cycle if weekday == "sunday" else "",
        weekday_cycle="" if weekday == "sunday" else weekday_cycle,
        special_day=special_day,
    )


def _normalized_source_reference(row: PsalmSourceRow) -> str:
    return normalize_reference(
        canonicalize_nigeria_reference(
            row.date_rule,
            row.reference_normalized,
        )
    )


def _load_csv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def _standard_matches(
    day: date,
    context: TemporalContext,
    standard_rows: Iterable[dict[str, str]],
    *,
    ignore_cycles: bool = False,
) -> list[dict[str, str]]:
    matches: list[dict[str, str]] = []
    for row in standard_rows:
        season = row["season"].strip().lower().replace(" ", "-")
        week = row["week"].strip().lower()
        weekday = row["day"].strip().lower()
        if context.special_day == "holy-thursday":
            matched = season == "holy-week" and weekday == "holy thursday"
        elif context.special_day.startswith("holy-week-"):
            matched = season == "holy-week" and weekday == context.weekday
        elif context.special_day == "good-friday":
            matched = season == "holy-week" and weekday == "good friday"
        elif context.special_day == "palm-sunday":
            matched = season == "holy-week" and weekday == "palm sunday"
        elif context.special_day == "easter-vigil":
            matched = season == "easter" and week == "vigil"
        elif context.special_day == "christmas-day":
            matched = season == "christmas" and "christmas" in weekday
        elif context.special_day == "ash-wednesday":
            matched = season == "lent" and weekday == "ash wednesday"
        elif context.special_day.startswith("after-ash-wednesday-"):
            matched = (
                season == "lent"
                and week == "after ash wed"
                and weekday == context.weekday
            )
        elif context.special_day.startswith("easter-octave-"):
            matched = (
                season == "easter"
                and week == "octave"
                and weekday == context.weekday
            )
        else:
            matched = season == context.season
            if matched and not ignore_cycles and row["sunday_cycle"].strip():
                matched = row["sunday_cycle"].strip().upper() in {
                    "A/B/C",
                    "ABC",
                    context.sunday_cycle,
                }
            if matched and not ignore_cycles and row["weekday_cycle"].strip():
                matched = row["weekday_cycle"].strip().upper() in {
                    "I/II",
                    context.weekday_cycle,
                }
            month_day = f"{day.strftime('%B')} {day.day}".lower()
            if matched and weekday == month_day:
                if context.season == "advent" and 17 <= day.day <= 24:
                    matched = week in {"dec 17-24", ""}
                elif (
                    context.season == "christmas"
                    and day.month == 12
                    and 26 <= day.day <= 31
                ):
                    matched = week in {"octave", ""}
                else:
                    matched = True
            elif matched:
                matched = (
                    weekday == context.weekday
                    and week == context.week
                )
        if matched:
            matches.append(row)
    return matches


_EXPLICIT_FORMS: dict[tuple[str, int], tuple[str, str, str]] = {
    ("2025-12-24", 2): ("celebration", "nativity_of_the_lord", "vigil"),
    ("2026-04-02", 1): ("celebration", "holy_thursday", "chrism"),
    ("2026-04-02", 2): ("celebration", "holy_thursday", "evening"),
    ("2026-05-23", 2): ("celebration", "pentecost_sunday", "vigil"),
    ("2026-06-28", 2): (
        "celebration",
        "saints_peter_and_paul_apostles",
        "vigil",
    ),
    ("2026-08-14", 2): (
        "celebration",
        "the_assumption_of_the_blessed_virgin_mary",
        "vigil",
    ),
}


_FIXED_PROPER_DATES: dict[tuple[int, int], str] = {
    (1, 1): "mary_mother_of_god",
    (1, 20): "cyprian_michael_iwene_tansi",
    (2, 2): "presentation_of_the_lord",
    (3, 17): "patrick_of_ireland",
    (3, 19): "saint_joseph_spouse_of_blessed_virgin_mary",
    (4, 25): "mark_evangelist",
    (4, 30): "our_lady_mother_of_africa",
    (6, 11): "saint_barnabas_apostle",
    (6, 24): "nativity_of_saint_john_the_baptist",
    (6, 29): "saints_peter_and_paul_apostles",
    (7, 3): "thomas_apostle",
    (7, 22): "mary_magdalene",
    (7, 25): "james_apostle",
    (8, 6): "transfiguration_of_the_lord",
    (8, 10): "lawrence_of_rome_deacon",
    (8, 15): "the_assumption_of_the_blessed_virgin_mary",
    (8, 24): "bartholomew_apostle",
    (8, 29): "passion_of_john_the_baptist",
    (9, 8): "nativity_of_blessed_virgin_mary",
    (9, 14): "exaltation_of_holy_cross",
    (9, 21): "matthew_apostle",
    (9, 29): "michael_gabriel_raphael_archangels",
    (10, 1): "our_lady_queen_of_nigeria",
    (10, 2): "guardian_angels",
    (10, 28): "simon_and_jude_apostles",
    (11, 1): "all_saints",
    (11, 2): "all_souls",
    (11, 9): "dedication_of_lateran_basilica",
    (11, 30): "andrew_apostle",
    (12, 8): "immaculate_conception_of_blessed_virgin_mary",
    (12, 25): "nativity_of_the_lord",
    (12, 26): "stephen_first_martyr",
    (12, 27): "john_apostle",
}


def _first_sunday_between(start: date, end: date) -> date:
    cursor = start
    while cursor <= end:
        if cursor.weekday() == 6:
            return cursor
        cursor += timedelta(days=1)
    raise ValueError(f"no Sunday between {start} and {end}")


def _holy_family(year: int) -> date:
    for day_number in range(26, 32):
        candidate = date(year, 12, day_number)
        if candidate.weekday() == 6:
            return candidate
    return date(year, 12, 30)


def _annunciation(year: int) -> date:
    nominal = date(year, 3, 25)
    easter = easter_sunday(year)
    if easter - timedelta(days=7) <= nominal <= easter + timedelta(days=7):
        return easter + timedelta(days=8)
    if nominal.weekday() == 6:
        return nominal + timedelta(days=1)
    return nominal


def proper_celebration_for_date(day: date) -> str | None:
    """Return the current Nigeria proper independently of source civil year."""
    easter = easter_sunday(day.year)
    advent = advent_start(day.year)
    epiphany = _first_sunday_between(
        date(day.year, 1, 2),
        date(day.year, 1, 8),
    )
    baptism = epiphany + timedelta(
        days=1 if epiphany.day in {7, 8} else 7
    )
    movable = {
        epiphany: "epiphany_of_the_lord",
        baptism: "baptism_of_the_lord",
        easter: "easter_sunday",
        easter + timedelta(days=39): "ascension_of_the_lord",
        easter + timedelta(days=49): "pentecost_sunday",
        easter + timedelta(days=50): "mary_mother_of_the_church",
        easter + timedelta(days=56): "most_holy_trinity",
        easter + timedelta(days=63): "body_and_blood_of_christ",
        easter + timedelta(days=68): "most_sacred_heart_of_jesus",
        easter + timedelta(days=69): "immaculate_heart_of_mary",
        advent - timedelta(days=7): "christ_the_king",
        _holy_family(day.year): "holy_family",
        _annunciation(day.year): "annunciation_of_the_lord",
    }
    return movable.get(day) or _FIXED_PROPER_DATES.get((day.month, day.day))


_CYCLE_SPECIFIC_PROPERS = {
    "epiphany_of_the_lord",
    "baptism_of_the_lord",
    "ascension_of_the_lord",
    "pentecost_sunday",
    "most_holy_trinity",
    "body_and_blood_of_christ",
    "most_sacred_heart_of_jesus",
    "christ_the_king",
    "easter_sunday",
}


_ALWAYS_PROPER_IDS = {
    "immaculate_conception_of_blessed_virgin_mary",
    "nativity_of_the_lord",
    "stephen_first_martyr",
    "john_apostle",
    "holy_family",
    "mary_mother_of_god",
    "epiphany_of_the_lord",
    "baptism_of_the_lord",
    "presentation_of_the_lord",
    "saint_joseph_spouse_of_blessed_virgin_mary",
    "annunciation_of_the_lord",
    "easter_sunday",
    "our_lady_mother_of_africa",
    "ascension_of_the_lord",
    "pentecost_sunday",
    "most_holy_trinity",
    "body_and_blood_of_christ",
    "most_sacred_heart_of_jesus",
    "nativity_of_saint_john_the_baptist",
    "saints_peter_and_paul_apostles",
    "transfiguration_of_the_lord",
    "the_assumption_of_the_blessed_virgin_mary",
    "exaltation_of_holy_cross",
    "our_lady_queen_of_nigeria",
    "all_saints",
    "all_souls",
    "christ_the_king",
}


def infer_nigeria_assignments(
    source_rows: Iterable[PsalmSourceRow],
    *,
    root: Path,
) -> tuple[list[NigeriaPsalmUsageAssignment], list[str]]:
    standard_rows = _load_csv(root / "standard_lectionary_complete.csv")
    memorial_rows = _load_csv(root / "memorial_feasts.csv")
    assignments: list[NigeriaPsalmUsageAssignment] = []
    unresolved: list[str] = []
    for source in source_rows:
        day = date.fromisoformat(source.date_rule)
        context = temporal_context(day)
        reference = _normalized_source_reference(source)
        source_response = normalize_words(source.response_raw)
        temporal_candidates = _standard_matches(
            day,
            context,
            standard_rows,
            ignore_cycles=True,
        )
        temporal_matches = [
            row
            for row in temporal_candidates
            if _same_numbered_selection(row["psalm_reference"], reference)
            or (
                source_response
                and normalize_words(row["psalm_response"]) == source_response
            )
        ]
        explicit = _EXPLICIT_FORMS.get(
            (source.date_rule, source.reading_set_priority)
        )
        if source.date_rule == "2026-04-04":
            assignments.append(
                NigeriaPsalmUsageAssignment(
                    source_selection_id=source.usage_id,
                    territory="NG",
                    kind="special-period",
                    special_day="easter-vigil",
                    choice_priority=source.reading_set_priority,
                    review_status="verified",
                )
            )
            continue
        if explicit is not None:
            _, celebration_id, mass_form = explicit
            assignments.append(
                NigeriaPsalmUsageAssignment(
                    source_selection_id=source.usage_id,
                    territory="NG",
                    kind="celebration",
                    celebration_id=celebration_id,
                    mass_form=mass_form,
                    choice_priority=source.reading_set_priority,
                    review_status="verified",
                )
            )
            continue

        proper_id = proper_celebration_for_date(day)
        if proper_id is not None:
            if proper_id not in _ALWAYS_PROPER_IDS and (
                day.weekday() == 6 or temporal_matches
            ):
                assignments.append(
                    NigeriaPsalmUsageAssignment(
                        source_selection_id=source.usage_id,
                        territory="NG",
                        kind="temporal",
                        season=context.season,
                        week=context.week,
                        weekday=context.weekday,
                        sunday_cycle=context.sunday_cycle,
                        weekday_cycle=context.weekday_cycle,
                        choice_priority=source.reading_set_priority,
                        review_status="verified",
                    )
                )
                continue
            assignments.append(
                NigeriaPsalmUsageAssignment(
                    source_selection_id=source.usage_id,
                    territory="NG",
                    kind="celebration",
                    celebration_id=proper_id,
                    mass_form="day",
                    sunday_cycle=(
                        context.sunday_cycle
                        if proper_id in _CYCLE_SPECIFIC_PROPERS
                        else ""
                    ),
                    choice_priority=source.reading_set_priority,
                    review_status="verified",
                )
            )
            continue

        if context.special_day in {
            "ash-wednesday",
            "palm-sunday",
            "good-friday",
        } or context.special_day.startswith(
            (
                "after-ash-wednesday-",
                "holy-week-",
                "easter-octave-",
                "advent-december-",
                "christmas-december-",
                "christmas-january-",
                "after-epiphany-",
            )
        ):
            assignments.append(
                NigeriaPsalmUsageAssignment(
                    source_selection_id=source.usage_id,
                    territory="NG",
                    kind="special-period",
                    special_day=context.special_day,
                    sunday_cycle=context.sunday_cycle,
                    weekday_cycle=context.weekday_cycle,
                    choice_priority=source.reading_set_priority,
                    review_status="verified",
                )
            )
            continue

        memorial_matches = [
            row
            for row in memorial_rows
            if row["month"].strip() == str(day.month)
            and row["day"].strip() == str(day.day)
            and normalize_reference(row["psalmReference"]) == reference
        ]
        if len(memorial_matches) == 1 and not temporal_matches:
            match = memorial_matches[0]
            assignments.append(
                NigeriaPsalmUsageAssignment(
                    source_selection_id=source.usage_id,
                    territory="NG",
                    kind="celebration",
                    celebration_id=match["id"],
                    mass_form="day",
                    choice_priority=source.reading_set_priority,
                    review_status="verified",
                )
            )
        elif temporal_matches:
            assignments.append(
                NigeriaPsalmUsageAssignment(
                    source_selection_id=source.usage_id,
                    territory="NG",
                    kind="temporal",
                    season=context.season,
                    week=context.week,
                    weekday=context.weekday,
                    sunday_cycle=context.sunday_cycle,
                    weekday_cycle=context.weekday_cycle,
                    choice_priority=source.reading_set_priority,
                    review_status="verified",
                )
            )
        else:
            assignments.append(
                NigeriaPsalmUsageAssignment(
                    source_selection_id=source.usage_id,
                    territory="NG",
                    kind="temporal",
                    season=context.season,
                    week=context.week,
                    weekday=context.weekday,
                    sunday_cycle=context.sunday_cycle,
                    weekday_cycle=context.weekday_cycle,
                    choice_priority=source.reading_set_priority,
                    review_status="verified",
                )
            )
    return assignments, unresolved


def _same_numbered_selection(first: str, second: str) -> bool:
    try:
        return selection_signature(first) == selection_signature(second)
    except ValueError:
        return normalize_reference(first) == normalize_reference(second)
