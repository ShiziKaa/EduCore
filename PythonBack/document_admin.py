"""Admin document constructor: parse, draft storage, paragraph serialization."""

from __future__ import annotations

import json
import os
import uuid
from typing import Any

from database_builder import (
    _read_docx,
    _read_txt,
    _read_xlsx,
    extract_news_metadata,
)

DRAFTS_DIR_NAME = ".drafts"


def drafts_dir(base_dir: str) -> str:
    path = os.path.join(base_dir, "data", DRAFTS_DIR_NAME)
    os.makedirs(path, exist_ok=True)
    return path


def _draft_path(base_dir: str, draft_id: str) -> str:
    return os.path.join(drafts_dir(base_dir), f"{draft_id}.json")


def _parse_chunk_metadata(text: str, metadata: dict[str, str], index: int) -> dict[str, Any]:
    images = [
        item.strip()
        for item in metadata.get("images", "").split(",")
        if item.strip()
    ]
    videos = [
        item.strip()
        for item in metadata.get("videos", "").split(",")
        if item.strip()
    ]
    audios = [
        item.strip()
        for item in metadata.get("audios", "").split(",")
        if item.strip()
    ]
    is_news = metadata.get("is_news") == "true"
    news_preview = metadata.get("news_preview") or None
    news_order: int | None = None
    raw_order = (metadata.get("news_order") or "").strip()
    if raw_order:
        try:
            news_order = int(raw_order)
        except ValueError:
            news_order = None

    return {
        "index": index,
        "text": text,
        "images": images,
        "videos": videos,
        "audios": audios,
        "is_news": is_news,
        "news_preview": news_preview,
        "news_order": news_order,
        "is_saved": False,
    }


def _parse_uploaded_file(path: str) -> list[dict[str, Any]]:
    lower = path.lower()
    if lower.endswith(".txt"):
        chunks = _read_txt(path)
    elif lower.endswith(".docx"):
        chunks = _read_docx(path)
    elif lower.endswith(".xlsx"):
        chunks = _read_xlsx(path)
    else:
        raise ValueError("Diňe .docx, .xlsx we .txt goldanylýar.")

    paragraphs: list[dict[str, Any]] = []
    for index, (text, metadata) in enumerate(chunks):
        paragraphs.append(_parse_chunk_metadata(text, metadata, index))
    return paragraphs


def create_draft_from_file(base_dir: str, source_path: str, filename: str) -> dict[str, Any]:
    draft_id = uuid.uuid4().hex
    stem = os.path.splitext(filename)[0]
    output_filename = f"{stem}_constructed.txt"

    draft = {
        "id": draft_id,
        "source_filename": filename,
        "output_filename": output_filename,
        "paragraphs": _parse_uploaded_file(source_path),
    }
    save_draft(base_dir, draft)
    return draft


def load_draft(base_dir: str, draft_id: str) -> dict[str, Any]:
    path = _draft_path(base_dir, draft_id)
    if not os.path.isfile(path):
        raise FileNotFoundError("Draft tapylmady.")
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def save_draft(base_dir: str, draft: dict[str, Any]) -> None:
    path = _draft_path(base_dir, draft["id"])
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(draft, handle, ensure_ascii=False, indent=2)


def serialize_paragraph(paragraph: dict[str, Any]) -> str:
    text = (paragraph.get("text") or "").strip()
    if not text:
        raise ValueError("Abzas boş bolup bilmez.")

    parts = [text]
    images = paragraph.get("images") or []
    videos = paragraph.get("videos") or []
    audios = paragraph.get("audios") or []

    if images:
        parts.append(f"[IMG: {', '.join(images)}]")
    if videos:
        parts.append(f"[VIDEO: {', '.join(videos)}]")
    if audios:
        parts.append(f"[AUDIO: {', '.join(audios)}]")
    if paragraph.get("is_news"):
        preview = (paragraph.get("news_preview") or "").strip()
        if not preview:
            raise ValueError("Möhüm habar üçin preview suraty hökmany.")
        parts.append("[News]")
        parts.append(f"[PREVIEW: {preview}]")
        order = paragraph.get("news_order")
        if order is not None and str(order).strip() != "":
            try:
                parts.append(f"[NEWS_ORDER: {int(order)}]")
            except (TypeError, ValueError) as exc:
                raise ValueError("NEWS_ORDER san bolmaly.") from exc

    return " ".join(parts)


def _apply_paragraph_payload(paragraph: dict[str, Any], payload: dict[str, Any]) -> None:
    paragraph["text"] = (payload.get("text") or "").strip()
    paragraph["images"] = list(payload.get("images") or [])
    paragraph["videos"] = list(payload.get("videos") or [])
    paragraph["audios"] = list(payload.get("audios") or [])
    paragraph["is_news"] = bool(payload.get("is_news"))
    paragraph["news_preview"] = payload.get("news_preview")

    if "news_order" in payload:
        raw_order = payload.get("news_order")
        if raw_order is None or str(raw_order).strip() == "":
            paragraph["news_order"] = None
        else:
            try:
                paragraph["news_order"] = int(raw_order)
            except (TypeError, ValueError) as exc:
                raise ValueError("NEWS_ORDER san bolmaly.") from exc

    if paragraph["is_news"] and not (paragraph.get("news_preview") or "").strip():
        raise ValueError("Möhüm habar üçin preview suraty hökmany.")

    serialize_paragraph(paragraph)


def update_paragraph(
    base_dir: str,
    draft_id: str,
    index: int,
    payload: dict[str, Any],
) -> dict[str, Any]:
    draft = load_draft(base_dir, draft_id)
    paragraphs = draft.get("paragraphs", [])
    if index < 0 or index >= len(paragraphs):
        raise IndexError("Abzas indeksi nädogry.")

    paragraph = paragraphs[index]
    _apply_paragraph_payload(paragraph, payload)
    paragraph["is_saved"] = True
    paragraphs[index] = paragraph
    draft["paragraphs"] = paragraphs
    save_draft(base_dir, draft)
    return draft


def finalize_draft(base_dir: str, draft_id: str) -> dict[str, Any]:
    draft = load_draft(base_dir, draft_id)
    paragraphs = draft.get("paragraphs", [])
    if not paragraphs:
        raise ValueError("Abzas ýok.")

    unsaved = [p["index"] + 1 for p in paragraphs if not p.get("is_saved")]
    if unsaved:
        raise ValueError(
            f"Ähli abzaslar ýazylmaly. Ýazylmadyk: {', '.join(map(str, unsaved))}"
        )

    blocks = [serialize_paragraph(p) for p in paragraphs]
    output_name = draft["output_filename"]
    output_path = os.path.join(base_dir, "data", output_name)
    with open(output_path, "w", encoding="utf-8") as handle:
        handle.write("\n\n".join(blocks))

    return {
        "status": "success",
        "filename": output_name,
        "paragraphs": len(paragraphs),
    }


def _data_dir(base_dir: str) -> str:
    path = os.path.join(base_dir, "data")
    os.makedirs(path, exist_ok=True)
    return path


def _safe_source_name(source: str) -> str:
    name = os.path.basename((source or "").strip())
    if not name or name in (".", "..") or "/" in source or "\\" in source:
        raise ValueError("Faýl ady nädogry.")
    if not name.lower().endswith(".txt"):
        raise ValueError("Diňe .txt faýllary redaktirlenýär.")
    if name.startswith("."):
        raise ValueError("Gizlin faýllar redaktirlenmeýär.")
    return name


def _source_path(base_dir: str, source: str) -> str:
    name = _safe_source_name(source)
    path = os.path.join(_data_dir(base_dir), name)
    if not os.path.isfile(path):
        raise FileNotFoundError(f"Faýl tapylmady: {name}")
    return path


def _list_txt_sources(base_dir: str) -> list[str]:
    data_dir = _data_dir(base_dir)
    names: list[str] = []
    for name in sorted(os.listdir(data_dir)):
        path = os.path.join(data_dir, name)
        if not os.path.isfile(path):
            continue
        if not name.lower().endswith(".txt"):
            continue
        if name.startswith("."):
            continue
        names.append(name)
    return names


def _load_source_paragraphs(base_dir: str, source: str) -> list[dict[str, Any]]:
    path = _source_path(base_dir, source)
    paragraphs = _parse_uploaded_file(path)
    for paragraph in paragraphs:
        paragraph["source"] = os.path.basename(path)
        paragraph["is_saved"] = True
    return paragraphs


def _write_source_paragraphs(
    base_dir: str,
    source: str,
    paragraphs: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    name = _safe_source_name(source)
    path = os.path.join(_data_dir(base_dir), name)
    if not paragraphs:
        raise ValueError("Abzas ýok — faýl boş goýulmaýar.")

    blocks = [serialize_paragraph(p) for p in paragraphs]
    with open(path, "w", encoding="utf-8") as handle:
        handle.write("\n\n".join(blocks))

    return _load_source_paragraphs(base_dir, name)


def _missing_media_for_paragraph(base_dir: str, paragraph: dict[str, Any]) -> list[str]:
    missing: list[str] = []
    checks = (
        ("images", paragraph.get("images") or []),
        ("videos", paragraph.get("videos") or []),
        ("audios", paragraph.get("audios") or []),
    )
    for folder, names in checks:
        for name in names:
            path = os.path.join(base_dir, folder, name)
            if not os.path.isfile(path):
                missing.append(f"{folder}/{name}")

    preview = (paragraph.get("news_preview") or "").strip()
    if preview:
        path = os.path.join(base_dir, "images", preview)
        if not os.path.isfile(path):
            missing.append(f"images/{preview}")

    return missing


def _enrich_paragraph(base_dir: str, paragraph: dict[str, Any]) -> dict[str, Any]:
    enriched = dict(paragraph)
    enriched["missing_media"] = _missing_media_for_paragraph(base_dir, paragraph)
    return enriched


def list_kb_paragraphs(
    base_dir: str,
    query: str = "",
    news_only: bool = False,
) -> dict[str, Any]:
    needle = (query or "").strip().casefold()
    paragraphs: list[dict[str, Any]] = []

    for source in _list_txt_sources(base_dir):
        for paragraph in _load_source_paragraphs(base_dir, source):
            if news_only and not paragraph.get("is_news"):
                continue
            text = paragraph.get("text") or ""
            if needle and needle not in text.casefold():
                continue
            paragraphs.append(_enrich_paragraph(base_dir, paragraph))

    stats = kb_stats(base_dir)
    return {
        "paragraphs": paragraphs,
        "stats": stats,
        "news_count": stats["news_count"],
    }


def update_kb_paragraph(
    base_dir: str,
    source: str,
    index: int,
    payload: dict[str, Any],
) -> dict[str, Any]:
    paragraphs = _load_source_paragraphs(base_dir, source)
    if index < 0 or index >= len(paragraphs):
        raise IndexError("Abzas indeksi nädogry.")

    paragraph = paragraphs[index]
    _apply_paragraph_payload(paragraph, payload)
    paragraphs[index] = paragraph
    updated = _write_source_paragraphs(base_dir, source, paragraphs)
    return {
        "status": "success",
        "source": _safe_source_name(source),
        "paragraph": _enrich_paragraph(base_dir, updated[index]),
        "paragraphs": [_enrich_paragraph(base_dir, p) for p in updated],
    }


def save_kb_file(
    base_dir: str,
    source: str,
    paragraphs_payload: list[dict[str, Any]],
) -> dict[str, Any]:
    name = _safe_source_name(source)
    if not paragraphs_payload:
        raise ValueError("Abzas ýok.")

    prepared: list[dict[str, Any]] = []
    for index, payload in enumerate(paragraphs_payload):
        paragraph: dict[str, Any] = {
            "index": index,
            "text": "",
            "images": [],
            "videos": [],
            "audios": [],
            "is_news": False,
            "news_preview": None,
            "news_order": None,
        }
        _apply_paragraph_payload(paragraph, payload)
        paragraph["index"] = index
        prepared.append(paragraph)

    updated = _write_source_paragraphs(base_dir, name, prepared)
    return {
        "status": "success",
        "source": name,
        "paragraphs": [_enrich_paragraph(base_dir, p) for p in updated],
    }


def add_kb_paragraph(
    base_dir: str,
    source: str,
    after_index: int | None = None,
    text: str = "Täze abzas",
) -> dict[str, Any]:
    paragraphs = _load_source_paragraphs(base_dir, source)
    new_paragraph: dict[str, Any] = {
        "index": 0,
        "text": (text or "Täze abzas").strip() or "Täze abzas",
        "images": [],
        "videos": [],
        "audios": [],
        "is_news": False,
        "news_preview": None,
        "news_order": None,
        "is_saved": True,
        "source": _safe_source_name(source),
    }

    if after_index is None or after_index < 0:
        insert_at = len(paragraphs)
    else:
        insert_at = min(after_index + 1, len(paragraphs))

    paragraphs.insert(insert_at, new_paragraph)
    for index, paragraph in enumerate(paragraphs):
        paragraph["index"] = index

    updated = _write_source_paragraphs(base_dir, source, paragraphs)
    return {
        "status": "success",
        "source": _safe_source_name(source),
        "inserted_index": insert_at,
        "paragraphs": [_enrich_paragraph(base_dir, p) for p in updated],
    }


def delete_kb_paragraph(base_dir: str, source: str, index: int) -> dict[str, Any]:
    paragraphs = _load_source_paragraphs(base_dir, source)
    if index < 0 or index >= len(paragraphs):
        raise IndexError("Abzas indeksi nädogry.")
    if len(paragraphs) <= 1:
        raise ValueError("Faýlda azyndan 1 abzas galmaly.")

    paragraphs.pop(index)
    for i, paragraph in enumerate(paragraphs):
        paragraph["index"] = i

    updated = _write_source_paragraphs(base_dir, source, paragraphs)
    return {
        "status": "success",
        "source": _safe_source_name(source),
        "paragraphs": [_enrich_paragraph(base_dir, p) for p in updated],
    }


def duplicate_kb_paragraph(base_dir: str, source: str, index: int) -> dict[str, Any]:
    paragraphs = _load_source_paragraphs(base_dir, source)
    if index < 0 or index >= len(paragraphs):
        raise IndexError("Abzas indeksi nädogry.")

    original = paragraphs[index]
    clone = {
        "index": index + 1,
        "text": original.get("text") or "",
        "images": list(original.get("images") or []),
        "videos": list(original.get("videos") or []),
        "audios": list(original.get("audios") or []),
        "is_news": bool(original.get("is_news")),
        "news_preview": original.get("news_preview"),
        "news_order": original.get("news_order"),
        "is_saved": True,
        "source": _safe_source_name(source),
    }
    paragraphs.insert(index + 1, clone)
    for i, paragraph in enumerate(paragraphs):
        paragraph["index"] = i

    updated = _write_source_paragraphs(base_dir, source, paragraphs)
    return {
        "status": "success",
        "source": _safe_source_name(source),
        "inserted_index": index + 1,
        "paragraphs": [_enrich_paragraph(base_dir, p) for p in updated],
    }


def kb_stats(base_dir: str) -> dict[str, Any]:
    paragraph_count = 0
    news_count = 0
    media_refs = 0
    missing_media = 0
    sources = _list_txt_sources(base_dir)

    for source in sources:
        for paragraph in _load_source_paragraphs(base_dir, source):
            paragraph_count += 1
            if paragraph.get("is_news"):
                news_count += 1
            media_refs += (
                len(paragraph.get("images") or [])
                + len(paragraph.get("videos") or [])
                + len(paragraph.get("audios") or [])
            )
            if paragraph.get("news_preview"):
                media_refs += 1
            missing_media += len(_missing_media_for_paragraph(base_dir, paragraph))

    return {
        "paragraph_count": paragraph_count,
        "news_count": news_count,
        "media_refs": media_refs,
        "missing_media": missing_media,
        "file_count": len(sources),
        "sources": sources,
    }


def export_paragraphs_text(paragraphs: list[dict[str, Any]]) -> str:
    blocks: list[str] = []
    for paragraph in paragraphs:
        blocks.append(serialize_paragraph(paragraph))
    return "\n\n".join(blocks)
