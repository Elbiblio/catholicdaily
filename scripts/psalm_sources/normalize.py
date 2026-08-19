from __future__ import annotations

from dataclasses import dataclass
import hashlib
import re
import unicodedata


@dataclass(frozen=True)
class ParsedPsalm:
    reference_raw: str
    reference_normalized: str
    response: str
    response_normalized: str
    stanzas: tuple[str, ...]
    stanzas_normalized: str
    raw_sha256: str
    normalized_sha256: str


def _clean_unicode(value: str) -> str:
    return (
        unicodedata.normalize("NFC", value)
        .replace("\u00a0", " ")
        .replace("–", "-")
        .replace("—", "-")
    )


def normalize_words(value: str) -> str:
    value = _clean_unicode(value).lower()
    value = re.sub(r"(?:^|\s)r\s*/?\.\s*", " ", value, flags=re.IGNORECASE)
    value = re.sub(r"[^\w']+", " ", value, flags=re.UNICODE)
    return " ".join(value.split())


def normalize_reference(value: str) -> str:
    value = _clean_unicode(value).lower().strip()
    value = value.replace("�", "-")
    value = re.sub(r"^[\s(\-]+", "", value)
    value = re.sub(r"^psalms?\s*,?\s*", "ps", value)
    value = re.sub(r"^ps\s*", "ps", value)
    value = re.sub(r"^psl(?=\s*:)", "ps1", value)
    value = re.sub(r"^dt\s*", "deuteronomy", value)
    if re.match(r"^\d+\s*:", value):
        value = "ps" + value
    value = re.sub(
        r"^([1-3]?[a-z]+)\s*(\d+)\s*[.:]\s*",
        r"\1\2:",
        value,
    )
    response_match = re.search(r"\(\s*r\s*/?\.\s*([^)]+)\)", value)
    response = ""
    if response_match:
        response = response_match.group(1)
        value = value[: response_match.start()] + value[response_match.end() :]
    value = re.sub(r"\b(?:cf\.?|see)\s*", "", value)
    value = value.replace(" and ", ",")
    value = re.sub(r"(?<=[0-9a-z])[.;]\s*(?=\d)", ",", value)
    value = re.sub(r"\s+", "", value)
    value = re.sub(r",+", ",", value).rstrip(",")
    if response:
        response = re.sub(r"\b(?:cf\.?|see)\s*", "", response)
        response = response.replace(" and ", ",")
        response = re.sub(r"\s+", "", response)
        value += f"(r.{response})"
    return value


def _strip_response_marker(value: str) -> str:
    value = re.sub(r"^\s*R\s*/?\.\s*", "", value, flags=re.IGNORECASE)
    value = re.sub(r"\s+R\s*/?\.\s*$", "", value, flags=re.IGNORECASE)
    return value.strip()


def _starts_with_response_marker(value: str) -> bool:
    return bool(re.match(r"^\s*R\s*/?\.", value, flags=re.IGNORECASE))


def parse_responsorial_section(section: str) -> ParsedPsalm:
    raw = _clean_unicode(section).strip()
    if re.match(
        r"^(?:ALLELUIA|GOSPEL|SECOND READING)\b",
        raw,
        flags=re.IGNORECASE,
    ):
        raise ValueError("not a responsorial psalm section")
    blocks = [
        block.strip()
        for block in re.split(r"\n\s*\n", raw)
        if block.strip()
    ]
    if len(blocks) < 2:
        raise ValueError("responsorial psalm has no text blocks")

    header_lines = blocks[0].splitlines()
    reference_raw = header_lines[0].strip()
    reference_normalized = normalize_reference(reference_raw)
    if not re.match(
        r"^(?:ps|isaiah|jeremiah|daniel|deuteronomy|"
        r"1samuel|1chronicles|exodus|luke)\d",
        reference_normalized,
        re.IGNORECASE,
    ):
        raise ValueError("responsorial psalm has an invalid reference")

    response = ""
    body_blocks: list[str] = []
    remainder = "\n".join(header_lines[1:]).strip()
    if remainder:
        if _starts_with_response_marker(remainder):
            response_lines = remainder.splitlines()
            response = _strip_response_marker(response_lines[0])
            if len(response_lines) > 1:
                body_blocks.append(
                    _strip_response_marker("\n".join(response_lines[1:]))
                )
        else:
            body_blocks.append(_strip_response_marker(remainder))

    for block in blocks[1:]:
        cleaned = _strip_response_marker(block)
        if _starts_with_response_marker(block):
            response_lines = block.splitlines()
            candidate = _strip_response_marker(response_lines[0])
            if not response:
                response = candidate
            elif normalize_words(candidate) != normalize_words(response):
                raise ValueError("responsorial psalm contains conflicting responses")
            if len(response_lines) > 1:
                body_blocks.append(
                    _strip_response_marker("\n".join(response_lines[1:]))
                )
            continue
        if response and normalize_words(cleaned) == normalize_words(response):
            continue
        body_blocks.append(cleaned)

    if not response or not body_blocks:
        raise ValueError("responsorial psalm is missing response or stanzas")

    stanzas = tuple(
        "\n".join(line.rstrip() for line in block.splitlines()).strip()
        for block in body_blocks
        if block.strip()
    )
    stanzas_normalized = "\n\n".join(
        normalize_words(stanza) for stanza in stanzas
    )
    whole = response + "\n\n" + "\n\n".join(stanzas)
    normalized_whole = normalize_words(response) + "\n\n" + stanzas_normalized
    return ParsedPsalm(
        reference_raw=reference_raw,
        reference_normalized=reference_normalized,
        response=response,
        response_normalized=normalize_words(response),
        stanzas=stanzas,
        stanzas_normalized=stanzas_normalized,
        raw_sha256=hashlib.sha256(whole.encode("utf-8")).hexdigest(),
        normalized_sha256=hashlib.sha256(
            normalized_whole.encode("utf-8")
        ).hexdigest(),
    )
