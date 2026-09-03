"""Query quality and relevance helpers for Bilim Çeşmesi search."""

from __future__ import annotations

import re

NOT_FOUND_MESSAGE = "Soragyňyz boýunça maglumat bazasynda maglumat ýok."

# Chroma default L2 distance on normalized e5 embeddings.
# Lower = closer. Tuned so random noise / weak matches are rejected.
MAX_ANSWER_DISTANCE = 0.78
MAX_RELATED_DISTANCE = 0.92
MAX_RELATED_ITEMS = 4

_LETTER_RE = re.compile(r"[A-Za-zÀ-ÖØ-öø-ÿĀ-žА-Яа-яЁёÄäÇçŇňÖöŞşÜüÝýŽž]+", re.UNICODE)
_TOKEN_RE = re.compile(r"[A-Za-zÀ-ÖØ-öø-ÿĀ-žА-Яа-яЁёÄäÇçŇňÖöŞşÜüÝýŽž0-9]{3,}", re.UNICODE)


def normalize_query(query: str) -> str:
    return " ".join((query or "").strip().split())


def is_meaningful_query(query: str) -> bool:
    text = normalize_query(query)
    if len(text) < 2:
        return False

    letters = _LETTER_RE.findall(text)
    letter_chars = sum(len(part) for part in letters)
    if letter_chars < 2:
        return False

    # Reject mostly-random digit/symbol strings.
    alnum = sum(1 for ch in text if ch.isalnum())
    if alnum == 0:
        return False

    if letter_chars / max(alnum, 1) < 0.35 and len(text) < 12:
        return False

    # Reject very short single-token gibberish ("asdf", "qwe", "x7k9").
    compact = re.sub(r"\s+", "", text)
    if " " not in text and len(compact) < 5:
        return False
    if " " not in text and len(compact) <= 8:
        vowels = set("aeiouyäöüýаеёиоуыэюяAEIOUYÄÖÜÝАЕЁИОУЫЭЮЯ")
        vowel_count = sum(1 for ch in compact if ch in vowels)
        if vowel_count == 0:
            return False

    return True


def extract_tokens(text: str) -> set[str]:
    return {token.lower() for token in _TOKEN_RE.findall(text or "")}


def has_lexical_overlap(query: str, document: str) -> bool:
    query_tokens = extract_tokens(query)
    if len(query_tokens) < 2:
        return True
    doc_tokens = extract_tokens(document)
    return bool(query_tokens & doc_tokens)


def is_relevant_match(query: str, document: str, distance: float) -> bool:
    if distance > MAX_ANSWER_DISTANCE:
        return False

    # Weak semantic matches without shared tokens are treated as misses.
    if distance > 0.62 and not has_lexical_overlap(query, document):
        return False

    return True


def make_suggestion_label(text: str, max_len: int = 56) -> str:
    clean = " ".join((text or "").strip().split())
    if not clean:
        return ""
    first_line = clean.split("\n", 1)[0].strip()
    if len(first_line) <= max_len:
        return first_line
    return first_line[: max_len - 1].rstrip() + "…"


def build_related_items(
    documents: list[str],
    distances: list[float],
    answer_text: str,
) -> list[dict[str, str]]:
    related: list[dict[str, str]] = []
    seen: set[str] = set()
    answer_key = " ".join(answer_text.strip().lower().split())
    if answer_key:
        seen.add(answer_key)

    for doc, distance in zip(documents, distances):
        if distance > MAX_RELATED_DISTANCE:
            continue
        clean = " ".join((doc or "").strip().split())
        if not clean:
            continue
        key = clean.lower()
        if key in seen:
            continue
        label = make_suggestion_label(clean)
        if not label:
            continue
        seen.add(key)
        related.append({"text": label, "query": label})
        if len(related) >= MAX_RELATED_ITEMS:
            break

    return related
