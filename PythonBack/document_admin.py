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
        is_news = metadata.get("is_news") == "true"
        news_preview = metadata.get("news_preview") or None
        paragraphs.append(
            {
                "index": index,
                "text": text,
                "images": images,
                "videos": videos,
                "is_news": is_news,
                "news_preview": news_preview,
                "is_saved": False,
            }
        )
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

    if images:
        parts.append(f"[IMG: {', '.join(images)}]")
    if videos:
        parts.append(f"[VIDEO: {', '.join(videos)}]")
    if paragraph.get("is_news"):
        preview = (paragraph.get("news_preview") or "").strip()
        if not preview:
            raise ValueError("Möhüm habar üçin preview suraty hökmany.")
        parts.append("[News]")
        parts.append(f"[PREVIEW: {preview}]")

    return " ".join(parts)


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
    paragraph["text"] = (payload.get("text") or "").strip()
    paragraph["images"] = list(payload.get("images") or [])
    paragraph["videos"] = list(payload.get("videos") or [])
    paragraph["is_news"] = bool(payload.get("is_news"))
    paragraph["news_preview"] = payload.get("news_preview")

    if paragraph["is_news"] and not (paragraph.get("news_preview") or "").strip():
        raise ValueError("Möhüm habar üçin preview suraty hökmany.")

    serialize_paragraph(paragraph)
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
