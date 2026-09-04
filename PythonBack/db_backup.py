"""Export / import Bilim Çeşmesi database folders as a ZIP archive."""

from __future__ import annotations

import os
import re
import shutil
import zipfile
from datetime import datetime

DB_CONTENT_FOLDERS = ("chroma_db", "data", "images", "videos", "audios")
DB_ROOT_FILES = ("welcome_settings.json",)
LOGO_PREFIX = "institute_logo."
LOGO_EXTENSIONS = (".png", ".jpg", ".jpeg")
BACKUPS_DIR_NAME = "backups"
AUTO_BACKUP_KEEP = 5
_AUTO_BACKUP_RE = re.compile(r"^auto_backup_\d{8}_\d{6}\.zip$", re.IGNORECASE)


def _iter_export_files(base_dir: str) -> list[tuple[str, str]]:
    """Return list of (absolute_path, archive_name) for DB content."""
    entries: list[tuple[str, str]] = []

    for folder in DB_CONTENT_FOLDERS:
        folder_path = os.path.join(base_dir, folder)
        if not os.path.isdir(folder_path):
            continue
        for root, _, files in os.walk(folder_path):
            for name in files:
                file_path = os.path.join(root, name)
                arcname = os.path.relpath(file_path, base_dir)
                entries.append((file_path, arcname.replace("\\", "/")))

    for name in DB_ROOT_FILES:
        file_path = os.path.join(base_dir, name)
        if os.path.isfile(file_path):
            entries.append((file_path, name))

    for ext in LOGO_EXTENSIONS:
        file_path = os.path.join(base_dir, f"institute_logo{ext}")
        if os.path.isfile(file_path):
            entries.append((file_path, f"institute_logo{ext}"))

    return entries


def create_export_zip(base_dir: str, zip_path: str) -> int:
    """Write a ZIP of the live DB content. Returns number of files packed."""
    parent = os.path.dirname(zip_path)
    if parent:
        os.makedirs(parent, exist_ok=True)

    entries = _iter_export_files(base_dir)
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as zipf:
        for file_path, arcname in entries:
            zipf.write(file_path, arcname)
    return len(entries)


def create_auto_backup(base_dir: str, keep: int = AUTO_BACKUP_KEEP) -> str:
    """
    Write a timestamped ZIP under backups/ and prune older auto backups.
    Returns the created zip filename (not full path).
    """
    backups_dir = os.path.join(base_dir, BACKUPS_DIR_NAME)
    os.makedirs(backups_dir, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"auto_backup_{stamp}.zip"
    zip_path = os.path.join(backups_dir, filename)
    create_export_zip(base_dir, zip_path)

    existing = sorted(
        (
            name
            for name in os.listdir(backups_dir)
            if _AUTO_BACKUP_RE.match(name)
            and os.path.isfile(os.path.join(backups_dir, name))
        ),
        reverse=True,
    )
    for stale in existing[max(0, keep) :]:
        try:
            os.remove(os.path.join(backups_dir, stale))
        except OSError:
            pass

    return filename


def _clear_db_content(base_dir: str) -> None:
    for folder in DB_CONTENT_FOLDERS:
        folder_path = os.path.join(base_dir, folder)
        if os.path.isdir(folder_path):
            shutil.rmtree(folder_path)
        os.makedirs(folder_path, exist_ok=True)

    for name in DB_ROOT_FILES:
        file_path = os.path.join(base_dir, name)
        if os.path.isfile(file_path):
            os.remove(file_path)

    for ext in LOGO_EXTENSIONS:
        file_path = os.path.join(base_dir, f"institute_logo{ext}")
        if os.path.isfile(file_path):
            os.remove(file_path)


def _is_safe_member(name: str) -> bool:
    normalized = name.replace("\\", "/").lstrip("/")
    if not normalized or normalized.startswith("../") or "/../" in f"/{normalized}/":
        return False
    if normalized.startswith("models/") or normalized.startswith("_internal/"):
        return False
    if normalized.endswith(".exe"):
        return False
    first = normalized.split("/", 1)[0]
    if first in DB_CONTENT_FOLDERS:
        return True
    if normalized in DB_ROOT_FILES:
        return True
    if normalized.startswith(LOGO_PREFIX) and any(
        normalized.lower().endswith(ext) for ext in LOGO_EXTENSIONS
    ):
        return True
    return False


def import_from_zip(base_dir: str, zip_path: str) -> int:
    """
    Replace DB content with archive contents.
    Caller must release any ChromaDB locks before calling this on Windows.
    Returns number of extracted files.
    """
    if not zipfile.is_zipfile(zip_path):
        raise ValueError("Saýlanan faýl zip däl ýa-da bozulan.")

    _clear_db_content(base_dir)

    extracted = 0
    with zipfile.ZipFile(zip_path, "r") as zipf:
        for info in zipf.infolist():
            if info.is_dir():
                continue
            name = info.filename.replace("\\", "/")
            if not _is_safe_member(name):
                continue
            target = os.path.normpath(os.path.join(base_dir, name))
            base_norm = os.path.normpath(base_dir)
            if not target.startswith(base_norm + os.sep) and target != base_norm:
                continue
            os.makedirs(os.path.dirname(target), exist_ok=True)
            with zipf.open(info) as source, open(target, "wb") as dest:
                shutil.copyfileobj(source, dest)
            extracted += 1

    for folder in DB_CONTENT_FOLDERS:
        os.makedirs(os.path.join(base_dir, folder), exist_ok=True)

    if extracted == 0:
        raise ValueError("Zip içinde maglumat bazasy tapylmady.")

    return extracted
