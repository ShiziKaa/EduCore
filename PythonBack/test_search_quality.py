"""Unit tests for search relevance / sanitization helpers."""

from __future__ import annotations

import unittest

from search_quality import (
    NOT_FOUND_MESSAGE,
    build_related_items,
    is_meaningful_query,
    is_relevant_match,
    make_suggestion_label,
    normalize_query,
)


class SearchSanitizationTests(unittest.TestCase):
    def test_rejects_empty_and_noise(self) -> None:
        self.assertFalse(is_meaningful_query(""))
        self.assertFalse(is_meaningful_query("   "))
        self.assertFalse(is_meaningful_query("12345"))
        self.assertFalse(is_meaningful_query("@@@###"))
        self.assertFalse(is_meaningful_query("q"))
        self.assertFalse(is_meaningful_query("asdf"))
        self.assertFalse(is_meaningful_query("x7k9"))

    def test_accepts_normal_questions(self) -> None:
        self.assertTrue(is_meaningful_query("Fakultetler haýsy?"))
        self.assertTrue(is_meaningful_query("Okuw tölegi näçe?"))
        self.assertTrue(is_meaningful_query("Кафедры института"))

    def test_distance_gate_rejects_weak_matches(self) -> None:
        self.assertFalse(is_relevant_match("random xyz", "Fakultetler barada", 0.95))
        self.assertFalse(
            is_relevant_match(
                "abc def ghi",
                "Institut taryhy we ösüşi",
                0.70,
            )
        )

    def test_distance_gate_accepts_strong_overlap(self) -> None:
        self.assertTrue(
            is_relevant_match(
                "fakultetler we kafedralar",
                "Institutyň fakultetler we kafedralar sanawy",
                0.45,
            )
        )

    def test_related_items_limit_and_dedupe(self) -> None:
        docs = [
            "Birinji tema barada maglumat",
            "Birinji tema barada maglumat",
            "Ikinji tema barada maglumat",
            "Üçünji tema",
            "Dördünji tema",
            "Bäşinji tema",
            "Altynjy tema",
        ]
        distances = [0.4, 0.41, 0.5, 0.55, 0.6, 0.65, 0.7]
        related = build_related_items(docs, distances, docs[0])
        self.assertLessEqual(len(related), 4)
        labels = [item["text"] for item in related]
        self.assertEqual(len(labels), len(set(labels)))
        self.assertNotIn(make_suggestion_label(docs[0]), labels)

    def test_not_found_message_is_turkmen(self) -> None:
        self.assertIn("maglumat", NOT_FOUND_MESSAGE.lower())
        self.assertEqual(normalize_query("  a  b  "), "a b")


if __name__ == "__main__":
    unittest.main()
