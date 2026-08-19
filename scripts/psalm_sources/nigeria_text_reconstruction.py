from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable, Mapping

from .liturgical_usage_universe import normalize_selection_reference
from .normalize import normalize_words
from .source_packs import RuntimePsalmPackRow


@dataclass(frozen=True)
class VerifiedPsalmFragment:
    fragment_key: str
    stanza_text: str
    source_selection_ids: tuple[str, ...]


@dataclass(frozen=True)
class NigeriaTextResolution:
    status: str
    stanzas_text: str
    source_selection_ids: tuple[str, ...]
    notes: str = ""


def _fragment_keys(reference: str) -> tuple[str, ...]:
    normalized = normalize_selection_reference(reference)
    if normalized.count(":") != 1 or ";" in normalized:
        return ()
    composition, selections = normalized.split(":", 1)
    parts = tuple(part.strip() for part in selections.split(",") if part.strip())
    if not composition or not parts:
        return ()
    return tuple(f"{composition}:{part}" for part in parts)


def _stanzas(value: str) -> tuple[str, ...]:
    return tuple(
        stanza.strip()
        for stanza in value.replace("\r\n", "\n").split("\n\n")
        if stanza.strip()
    )


def build_verified_fragment_index(
    rows: Iterable[RuntimePsalmPackRow],
) -> dict[str, VerifiedPsalmFragment]:
    candidates: dict[str, dict[str, tuple[str, list[str]]]] = {}
    for row in rows:
        fragment_keys = _fragment_keys(row.reference_normalized)
        stanzas = _stanzas(row.stanzas_text)
        if not fragment_keys or len(fragment_keys) != len(stanzas):
            continue
        for fragment_key, stanza in zip(fragment_keys, stanzas):
            normalized_text = normalize_words(stanza)
            if not normalized_text:
                continue
            variants = candidates.setdefault(fragment_key, {})
            stored = variants.setdefault(normalized_text, (stanza, []))
            if row.selection_id not in stored[1]:
                stored[1].append(row.selection_id)

    verified: dict[str, VerifiedPsalmFragment] = {}
    for fragment_key, variants in candidates.items():
        if len(variants) != 1:
            continue
        stanza_text, selection_ids = next(iter(variants.values()))
        verified[fragment_key] = VerifiedPsalmFragment(
            fragment_key=fragment_key,
            stanza_text=stanza_text,
            source_selection_ids=tuple(sorted(selection_ids)),
        )
    return verified


def reconstruct_nigeria_selection(
    reference: str,
    response_text: str,
    rows: Iterable[RuntimePsalmPackRow],
    fragment_index: Mapping[str, VerifiedPsalmFragment],
) -> NigeriaTextResolution:
    normalized_reference = normalize_selection_reference(reference)
    normalized_response = normalize_words(response_text)
    for row in rows:
        if (
            normalize_selection_reference(row.reference_normalized)
            == normalized_reference
            and normalize_words(row.response_text) == normalized_response
        ):
            return NigeriaTextResolution(
                status="exact_nigeria",
                stanzas_text=row.stanzas_text.strip(),
                source_selection_ids=(row.selection_id,),
                notes="Exact Nigerian reference and response match.",
            )

    keys = _fragment_keys(normalized_reference)
    if not keys or any(key not in fragment_index for key in keys):
        return NigeriaTextResolution(
            status="fallback",
            stanzas_text="",
            source_selection_ids=(),
            notes="Complete verified Nigerian verse fragments are unavailable.",
        )

    fragments = tuple(fragment_index[key] for key in keys)
    source_ids: list[str] = []
    for fragment in fragments:
        for selection_id in fragment.source_selection_ids:
            if selection_id not in source_ids:
                source_ids.append(selection_id)
    return NigeriaTextResolution(
        status="reconstructed_nigeria",
        stanzas_text="\n\n".join(fragment.stanza_text for fragment in fragments),
        source_selection_ids=tuple(source_ids),
        notes="Reconstructed only from exact verified Nigerian stanza fragments.",
    )
