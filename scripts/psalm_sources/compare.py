from __future__ import annotations

from dataclasses import replace
from difflib import SequenceMatcher

from .models import PsalmSourceRow
from .normalize import normalize_words


def similarity(left: str, right: str) -> float:
    return round(
        SequenceMatcher(
            None,
            normalize_words(left),
            normalize_words(right),
        ).ratio(),
        6,
    )


def classify_difference(left: str, right: str) -> str:
    if left == right:
        return "exact"
    if not left.strip() or not right.strip():
        return "missing_text"
    if normalize_words(left) == normalize_words(right):
        return "punctuation_only"
    if left.casefold() == right.casefold():
        return "orthography_only"
    return "translation_variant"


def compare_rows(left: PsalmSourceRow, right: PsalmSourceRow) -> dict[str, str]:
    if left.reference_normalized != right.reference_normalized:
        difference_class = "selection_mismatch"
    elif (
        left.response_normalized != right.response_normalized
        and left.stanzas_normalized == right.stanzas_normalized
    ):
        difference_class = "response_only"
    elif (
        normalize_words(left.stanzas_normalized)
        == normalize_words(right.stanzas_normalized)
        and left.stanzas_normalized != right.stanzas_normalized
    ):
        difference_class = "stanza_boundary_only"
    else:
        difference_class = classify_difference(
            left.response_raw + "\n" + left.stanzas_raw,
            right.response_raw + "\n" + right.stanzas_raw,
        )
    return {
        "reference_match_score": (
            "1.0"
            if left.reference_normalized == right.reference_normalized
            else "0.0"
        ),
        "response_match_score": str(
            similarity(left.response_normalized, right.response_normalized)
        ),
        "stanza_match_score": str(
            similarity(left.stanzas_normalized, right.stanzas_normalized)
        ),
        "text_match_score": str(
            similarity(
                left.response_normalized + " " + left.stanzas_normalized,
                right.response_normalized + " " + right.stanzas_normalized,
            )
        ),
        "difference_class": difference_class,
    }


def redact_for_commit(row: PsalmSourceRow) -> PsalmSourceRow:
    if row.reuse_status in {"open", "public_domain", "licensed"}:
        return row
    diagnostic = " ".join(
        (
            row.response_normalized + " " + row.stanzas_normalized
        ).split()[:12]
    )
    note = " ".join(
        part for part in (row.notes, f"diagnostic={diagnostic}") if part
    )[:240]
    return replace(
        row,
        response_raw="",
        stanzas_raw="",
        stanzas_normalized="",
        notes=note,
    )
