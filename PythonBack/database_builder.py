import os
import re
import sys
from typing import Any

from docx import Document
from openpyxl import load_workbook
from sentence_transformers import SentenceTransformer

IMAGE_TAG_RE = re.compile(
    r"\[(?:images?|img)\s*:\s*([^\]]+)\]",
    re.IGNORECASE,
)
VIDEO_TAG_RE = re.compile(
    r"\[(?:videos?|vid|video)\s*:\s*([^\]]+)\]",
    re.IGNORECASE,
)


def _split_media(raw: str) -> list[str]:
    return [item.strip() for item in raw.split(",") if item.strip()]


def extract_media_tags(text: str) -> tuple[str, dict[str, str]]:
    return _extract_media_tags(text)


def _extract_media_tags(text: str) -> tuple[str, dict[str, str]]:
    images: list[str] = []
    videos: list[str] = []

    for match in IMAGE_TAG_RE.finditer(text):
        images.extend(_split_media(match.group(1)))

    for match in VIDEO_TAG_RE.finditer(text):
        videos.extend(_split_media(match.group(1)))

    clean_text = VIDEO_TAG_RE.sub("", IMAGE_TAG_RE.sub("", text))
    clean_text = re.sub(r"\n{3,}", "\n\n", clean_text).strip()

    metadata: dict[str, str] = {}
    if images:
        metadata["images"] = ", ".join(dict.fromkeys(images))
    if videos:
        metadata["videos"] = ", ".join(dict.fromkeys(videos))

    return clean_text, metadata


def _read_txt(path: str) -> list[tuple[str, dict[str, str]]]:
    with open(path, "r", encoding="utf-8") as handle:
        raw_text = handle.read()

    chunks: list[tuple[str, dict[str, str]]] = []
    for paragraph in raw_text.split("\n\n"):
        paragraph = paragraph.strip()
        if not paragraph:
            continue
        clean_text, metadata = _extract_media_tags(paragraph)
        if clean_text:
            chunks.append((clean_text, metadata))
    return chunks


def _read_docx(path: str) -> list[tuple[str, dict[str, str]]]:
    document = Document(path)
    paragraphs = [p.text.strip() for p in document.paragraphs if p.text.strip()]
    raw_text = "\n\n".join(paragraphs)
    return _read_txt_from_string(raw_text)


def _read_xlsx(path: str) -> list[tuple[str, dict[str, str]]]:
    workbook = load_workbook(path, read_only=True, data_only=True)
    rows: list[str] = []

    for sheet in workbook.worksheets:
        for row in sheet.iter_rows(values_only=True):
            values = [str(value).strip() for value in row if value not in (None, "")]
            if values:
                rows.append(" | ".join(values))

    workbook.close()
    return _read_txt_from_string("\n\n".join(rows))


def _read_txt_from_string(raw_text: str) -> list[tuple[str, dict[str, str]]]:
    chunks: list[tuple[str, dict[str, str]]] = []
    for paragraph in raw_text.split("\n\n"):
        paragraph = paragraph.strip()
        if not paragraph:
            continue
        clean_text, metadata = _extract_media_tags(paragraph)
        if clean_text:
            chunks.append((clean_text, metadata))
    return chunks


def _collect_documents(data_dir: str) -> list[tuple[str, dict[str, str], str]]:
    documents: list[tuple[str, dict[str, str], str]] = []

    if not os.path.isdir(data_dir):
        return documents

    for filename in sorted(os.listdir(data_dir)):
        lower_name = filename.lower()
        path = os.path.join(data_dir, filename)

        if lower_name.endswith(".txt"):
            reader = _read_txt
        elif lower_name.endswith(".docx"):
            reader = _read_docx
        elif lower_name.endswith(".xlsx"):
            reader = _read_xlsx
        else:
            continue

        for index, (text, metadata) in enumerate(reader(path)):
            documents.append((text, metadata, f"{filename}#{index}"))

    return documents


def build_database(
    base_dir: str,
    model: SentenceTransformer | None = None,
    collection: Any | None = None,
) -> dict[str, Any]:
    data_dir = os.path.join(base_dir, "data")
    chroma_path = os.path.join(base_dir, "chroma_db")
    models_path = os.path.join(base_dir, "models")

    os.makedirs(data_dir, exist_ok=True)
    os.makedirs(models_path, exist_ok=True)
    os.environ["SENTENCE_TRANSFORMERS_HOME"] = models_path
    os.environ["HF_HOME"] = models_path

    if model is None:
        model = SentenceTransformer("intfloat/multilingual-e5-base", device="cpu")

    if collection is None:
        import chromadb

        db_client = chromadb.PersistentClient(path=chroma_path)
        collection = db_client.get_or_create_collection(name="tdbsi_history")

    documents = _collect_documents(data_dir)
    if not documents:
        return {
            "status": "error",
            "message": "data/ papkasynda faýl tapylmady.",
            "chunks": 0,
        }

    try:
        existing = collection.get(include=[])
        if existing.get("ids"):
            collection.delete(ids=existing["ids"])
    except Exception:
        pass

    texts: list[str] = []
    metadatas: list[dict[str, str]] = []
    ids: list[str] = []
    embeddings: list[list[float]] = []

    for index, (text, metadata, source_id) in enumerate(documents):
        prepared_text = f"passage: {text}"
        embeddings.append(model.encode(prepared_text).tolist())
        texts.append(text)
        record_metadata = dict(metadata)
        record_metadata.setdefault("source", source_id)
        metadatas.append(record_metadata)
        ids.append(f"doc_{index}_{source_id}")

    collection.add(
        embeddings=embeddings,
        documents=texts,
        metadatas=metadatas,
        ids=ids,
    )

    return {
        "status": "success",
        "message": "ChromaDB üstünlikli täzelendi.",
        "chunks": len(texts),
    }


def _resolve_base_dir() -> str:
    env_dir = os.environ.get("EDUCORE_DB_DIR")
    if env_dir and os.path.isdir(env_dir):
        return env_dir

    if getattr(sys, "frozen", False):
        exe_dir = os.path.dirname(sys.executable)
        parent_dir = os.path.dirname(exe_dir)
        if os.path.isfile(os.path.join(parent_dir, "search_engine.exe")):
            return parent_dir
        return exe_dir

    return os.path.dirname(os.path.abspath(__file__))


if __name__ == "__main__":
    result = build_database(_resolve_base_dir())
    print(result)
