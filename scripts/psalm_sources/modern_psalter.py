from __future__ import annotations

from html import unescape
import re
from urllib.parse import parse_qs, urlparse


def _text(html: str) -> str:
    value = re.sub(r"<script\b.*?</script>", " ", html, flags=re.I | re.S)
    value = re.sub(r"<style\b.*?</style>", " ", value, flags=re.I | re.S)
    value = re.sub(r"<[^>]+>", " ", value)
    return " ".join(unescape(value).split())


def parse_liturgy_page(html: str, url: str) -> dict[str, str]:
    query = parse_qs(urlparse(url).query)
    lectionary_number = query.get("n", [""])[0]
    text = _text(html)
    title_match = re.search(
        r"Psalms?\s+for\s+(.+?)(?:United States|The English translation)",
        text,
        flags=re.I,
    )
    return {
        "source_id": "modern_psalter_us",
        "title": title_match.group(1).strip() if title_match else "",
        "territory": "US,PH",
        "lectionary_number": lectionary_number,
        "reuse_status": "comparison_only",
        "source_url": url,
        "license_notice": (
            "ICEL Lectionary response and Gospel verse copyright notice"
            if "International Committee on English in the Liturgy" in text
            else ""
        ),
    }
