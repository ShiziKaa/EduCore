"""Tests for Bilim Çeşmesi DB export/import ZIP helpers."""

from __future__ import annotations

import os
import tempfile
import unittest
import zipfile

from db_backup import create_export_zip, import_from_zip


class DbBackupTests(unittest.TestCase):
    def _seed_db(self, root: str) -> None:
        for folder in ("chroma_db", "data", "images", "videos", "audios"):
            os.makedirs(os.path.join(root, folder), exist_ok=True)
        with open(os.path.join(root, "data", "doc.txt"), "w", encoding="utf-8") as handle:
            handle.write("Abzas bir.\n")
        with open(
            os.path.join(root, "images", "photo.png"), "wb"
        ) as handle:
            handle.write(b"\x89PNG\r\n")
        with open(
            os.path.join(root, "chroma_db", "chroma.sqlite3"), "wb"
        ) as handle:
            handle.write(b"sqlite-fake")
        with open(
            os.path.join(root, "welcome_settings.json"), "w", encoding="utf-8"
        ) as handle:
            handle.write('{"title":"Salam"}')
        with open(os.path.join(root, "institute_logo.png"), "wb") as handle:
            handle.write(b"logo")
        # Should never be imported from a zip
        os.makedirs(os.path.join(root, "models"), exist_ok=True)
        with open(os.path.join(root, "models", "big.bin"), "wb") as handle:
            handle.write(b"model")

    def test_export_import_roundtrip(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            source = os.path.join(tmp, "source")
            target = os.path.join(tmp, "target")
            os.makedirs(source)
            os.makedirs(target)
            self._seed_db(source)

            zip_path = os.path.join(tmp, "backup.zip")
            packed = create_export_zip(source, zip_path)
            self.assertGreaterEqual(packed, 4)
            self.assertTrue(zipfile.is_zipfile(zip_path))

            # Seed target with junk that must be replaced
            os.makedirs(os.path.join(target, "data"), exist_ok=True)
            with open(
                os.path.join(target, "data", "old.txt"), "w", encoding="utf-8"
            ) as handle:
                handle.write("old")

            extracted = import_from_zip(target, zip_path)
            self.assertGreaterEqual(extracted, 4)
            self.assertTrue(
                os.path.isfile(os.path.join(target, "data", "doc.txt"))
            )
            self.assertFalse(
                os.path.isfile(os.path.join(target, "data", "old.txt"))
            )
            self.assertTrue(
                os.path.isfile(os.path.join(target, "welcome_settings.json"))
            )
            self.assertTrue(
                os.path.isfile(os.path.join(target, "institute_logo.png"))
            )
            self.assertTrue(
                os.path.isfile(
                    os.path.join(target, "chroma_db", "chroma.sqlite3")
                )
            )
            self.assertFalse(
                os.path.isfile(os.path.join(target, "models", "big.bin"))
            )

    def test_rejects_non_zip(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            fake = os.path.join(tmp, "not.zip")
            with open(fake, "w", encoding="utf-8") as handle:
                handle.write("nope")
            with self.assertRaises(ValueError):
                import_from_zip(tmp, fake)

    def test_rejects_path_traversal(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            base = os.path.join(tmp, "base")
            os.makedirs(base)
            for folder in ("chroma_db", "data", "images", "videos", "audios"):
                os.makedirs(os.path.join(base, folder), exist_ok=True)

            zip_path = os.path.join(tmp, "evil.zip")
            with zipfile.ZipFile(zip_path, "w") as zipf:
                zipf.writestr("../escape.txt", "hacked")
                zipf.writestr("data/ok.txt", "safe")

            import_from_zip(base, zip_path)
            self.assertTrue(os.path.isfile(os.path.join(base, "data", "ok.txt")))
            self.assertFalse(os.path.isfile(os.path.join(tmp, "escape.txt")))


if __name__ == "__main__":
    unittest.main()
