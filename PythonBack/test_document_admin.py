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
    list_kb_paragraphs,
    serialize_paragraph,
    update_kb_paragraph,
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

    def test_serialize_includes_news_order(self) -> None:
        result = serialize_paragraph(
            {
                "text": "Habar",
                "is_news": True,
                "news_preview": "cover.png",
                "news_order": 3,
            }
        )
        self.assertIn("[News]", result)
        self.assertIn("[PREVIEW: cover.png]", result)
        self.assertIn("[NEWS_ORDER: 3]", result)
        clean, metadata = extract_news_metadata(result)
        self.assertEqual(clean, "Habar")
        self.assertEqual(metadata.get("news_order"), "3")


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


class KbEditorTests(unittest.TestCase):
    def test_list_update_and_search(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            data_dir = os.path.join(tmp, "data")
            os.makedirs(data_dir, exist_ok=True)
            path = os.path.join(data_dir, "live.txt")
            with open(path, "w", encoding="utf-8") as handle:
                handle.write(
                    "Fakultetler barada.\n\n"
                    "Sport habarlary. [News] [PREVIEW: sport.jpg] [NEWS_ORDER: 1]"
                )

            listed = list_kb_paragraphs(tmp)
            self.assertEqual(len(listed["paragraphs"]), 2)
            self.assertEqual(listed["stats"]["news_count"], 1)

            filtered = list_kb_paragraphs(tmp, query="sport", news_only=True)
            self.assertEqual(len(filtered["paragraphs"]), 1)

            updated = update_kb_paragraph(
                tmp,
                "live.txt",
                0,
                {
                    "text": "Fakultetler täzelendi.",
                    "images": [],
                    "videos": [],
                    "audios": [],
                    "is_news": False,
                    "news_preview": None,
                },
            )
            self.assertEqual(updated["paragraph"]["text"], "Fakultetler täzelendi.")
            with open(path, "r", encoding="utf-8") as handle:
                content = handle.read()
            self.assertIn("Fakultetler täzelendi.", content)

    def test_add_duplicate_delete_and_missing_media(self) -> None:
        from document_admin import (
            add_kb_paragraph,
            delete_kb_paragraph,
            duplicate_kb_paragraph,
        )

        with tempfile.TemporaryDirectory() as tmp:
            data_dir = os.path.join(tmp, "data")
            os.makedirs(data_dir, exist_ok=True)
            os.makedirs(os.path.join(tmp, "images"), exist_ok=True)
            path = os.path.join(data_dir, "live.txt")
            with open(path, "w", encoding="utf-8") as handle:
                handle.write("Birinji. [IMG: missing.png]")

            listed = list_kb_paragraphs(tmp)
            self.assertEqual(listed["paragraphs"][0]["missing_media"], ["images/missing.png"])
            self.assertEqual(listed["stats"]["missing_media"], 1)

            added = add_kb_paragraph(tmp, "live.txt", after_index=0, text="Ikinji")
            self.assertEqual(len(added["paragraphs"]), 2)
            self.assertEqual(added["inserted_index"], 1)

            dup = duplicate_kb_paragraph(tmp, "live.txt", 0)
            self.assertEqual(len(dup["paragraphs"]), 3)

            deleted = delete_kb_paragraph(tmp, "live.txt", 2)
            self.assertEqual(len(deleted["paragraphs"]), 2)

            delete_kb_paragraph(tmp, "live.txt", 1)
            with self.assertRaises(ValueError):
                delete_kb_paragraph(tmp, "live.txt", 0)


if __name__ == "__main__":
    unittest.main()
