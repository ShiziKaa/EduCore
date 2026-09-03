"""Sanitization and smoke tests for Bilim Çeşmesi document admin."""

from __future__ import annotations

import json
import os
import tempfile
import unittest

from database_builder import extract_news_metadata
from document_admin import (
    create_draft_from_file,
    finalize_draft,
    serialize_paragraph,
    update_paragraph,
)


class SanitizationTests(unittest.TestCase):
    def test_extract_news_metadata_strips_tags(self) -> None:
        text = "Salam [News] [PREVIEW: cover.png] [IMG: a.jpg] [AUDIO: voice.mp3]"
        clean, metadata = extract_news_metadata(text)
        self.assertNotIn("[News]", clean)
        self.assertNotIn("[PREVIEW:", clean)
        self.assertNotIn("[IMG:", clean)
        self.assertNotIn("[AUDIO:", clean)
        self.assertEqual(metadata.get("is_news"), "true")
        self.assertEqual(metadata.get("news_preview"), "cover.png")
        self.assertIn("a.jpg", metadata.get("images", ""))
        self.assertIn("voice.mp3", metadata.get("audios", ""))

    def test_serialize_rejects_empty_paragraph(self) -> None:
        with self.assertRaises(ValueError):
            serialize_paragraph({"text": "   "})

    def test_serialize_rejects_news_without_preview(self) -> None:
        with self.assertRaises(ValueError):
            serialize_paragraph(
                {
                    "text": "Habar",
                    "is_news": True,
                    "news_preview": "",
                }
            )

    def test_serialize_includes_audio_tag(self) -> None:
        result = serialize_paragraph(
            {
                "text": "Sesli maglumat",
                "images": [],
                "videos": [],
                "audios": ["hello.mp3"],
                "is_news": False,
            }
        )
        self.assertIn("[AUDIO: hello.mp3]", result)
        self.assertTrue(result.startswith("Sesli maglumat"))


class SmokeDraftFlowTests(unittest.TestCase):
    def test_create_update_finalize_roundtrip(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            source = os.path.join(tmp, "sample.txt")
            with open(source, "w", encoding="utf-8") as handle:
                handle.write("Birinji abzas.\n\nIkinji abzas.")

            draft = create_draft_from_file(tmp, source, "sample.txt")
            self.assertEqual(len(draft["paragraphs"]), 2)
            self.assertFalse(draft["paragraphs"][0]["is_saved"])

            updated = update_paragraph(
                tmp,
                draft["id"],
                0,
                {
                    "text": "Birinji abzas täzelendi.",
                    "images": [],
                    "videos": [],
                    "audios": ["clip.mp3"],
                    "is_news": False,
                    "news_preview": None,
                },
            )
            self.assertTrue(updated["paragraphs"][0]["is_saved"])
            self.assertEqual(updated["paragraphs"][0]["audios"], ["clip.mp3"])

            update_paragraph(
                tmp,
                draft["id"],
                1,
                {
                    "text": "Ikinji abzas täzelendi.",
                    "images": [],
                    "videos": [],
                    "audios": [],
                    "is_news": False,
                    "news_preview": None,
                },
            )

            result = finalize_draft(tmp, draft["id"])
            self.assertEqual(result["status"], "success")
            output_path = os.path.join(tmp, "data", result["filename"])
            self.assertTrue(os.path.isfile(output_path))
            with open(output_path, "r", encoding="utf-8") as handle:
                content = handle.read()
            self.assertIn("[AUDIO: clip.mp3]", content)
            self.assertIn("Birinji abzas täzelendi.", content)

            draft_path = os.path.join(tmp, "data", ".drafts", f"{draft['id']}.json")
            with open(draft_path, "r", encoding="utf-8") as handle:
                persisted = json.load(handle)
            self.assertEqual(len(persisted["paragraphs"]), 2)


if __name__ == "__main__":
    unittest.main()
