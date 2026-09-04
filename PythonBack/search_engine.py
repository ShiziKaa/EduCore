import os
import sys
import shutil
import uuid

os.environ.setdefault("PYTHONUTF8", "1")
os.environ.setdefault("HF_HUB_DISABLE_PROGRESS_BARS", "1")
os.environ.setdefault("TRANSFORMERS_VERBOSITY", "error")
os.environ.setdefault("TQDM_DISABLE", "1")

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
elif hasattr(sys.stdout, "buffer"):
    import io

    sys.stdout = io.TextIOWrapper(
        sys.stdout.buffer, encoding="utf-8", line_buffering=True
    )

from fastapi import BackgroundTasks, FastAPI, File, Query, UploadFile, HTTPException
from fastapi.responses import FileResponse
from pydantic import BaseModel
from sentence_transformers import SentenceTransformer
import chromadb
import uvicorn
import tempfile
import gc
import time
from starlette.background import BackgroundTask

from database_builder import build_database, extract_news_metadata
from db_backup import create_auto_backup, create_export_zip, import_from_zip
from document_admin import (
    add_kb_paragraph,
    create_draft_from_file,
    delete_kb_paragraph,
    drafts_dir,
    duplicate_kb_paragraph,
    export_paragraphs_text,
    finalize_draft,
    kb_stats,
    list_kb_paragraphs,
    load_draft,
    save_kb_file,
    update_kb_paragraph,
    update_paragraph,
)
from search_quality import (
    NOT_FOUND_MESSAGE,
    build_related_items,
    is_meaningful_query,
    is_relevant_match,
    normalize_query,
)

app = FastAPI(title="Bilim Çeşmesi AI Reactive Engine")


def _app_base_dir() -> str:
    env_dir = os.environ.get("EDUCORE_DB_DIR")
    if env_dir and os.path.isdir(env_dir):
        return env_dir

    if getattr(sys, "frozen", False):
        return os.path.dirname(sys.executable)

    return os.path.dirname(os.path.abspath(__file__))


def _models_ready(models_path: str) -> bool:
    if not os.path.isdir(models_path):
        return False

    for root, _, files in os.walk(models_path):
        for name in files:
            lower = name.lower()
            if lower.endswith((".bin", ".safetensors", ".onnx", ".pt")):
                return True
    return False


base_dir = _app_base_dir()
chroma_path = os.path.join(base_dir, "chroma_db")
models_path = os.path.join(base_dir, "models")
data_dir = os.path.join(base_dir, "data")
images_dir = os.path.join(base_dir, "images")
videos_dir = os.path.join(base_dir, "videos")
audios_dir = os.path.join(base_dir, "audios")

for folder in [models_path, data_dir, images_dir, videos_dir, audios_dir, chroma_path]:
    os.makedirs(folder, exist_ok=True)

os.environ["SENTENCE_TRANSFORMERS_HOME"] = models_path
os.environ["HF_HOME"] = models_path
if _models_ready(models_path):
    os.environ["HF_HUB_OFFLINE"] = "1"
    os.environ["TRANSFORMERS_OFFLINE"] = "1"

print("Bilim Çeşmesi: Инициализация ChromaDB...")
db_client = chromadb.PersistentClient(path=chroma_path)
collection = db_client.get_or_create_collection(name="tdbsi_history")

device = "cpu"
print(f"Bilim Çeşmesi: Загрузка ИИ-модели на {device.upper()}... (Ждите, идет прогрев)")
model = SentenceTransformer("intfloat/multilingual-e5-base", device=device)
print("Bilim Çeşmesi AI микросервис успешно запущен и готов к работе!")


@app.get("/health")
def health_check():
    return {"status": "ok", "service": "bilim-cesmesi"}


def _not_found_payload() -> dict:
    return {
        "status": "not_found",
        "found": False,
        "answer": NOT_FOUND_MESSAGE,
        "distance": None,
        "images": [],
        "videos": [],
        "audios": [],
        "related": [],
    }


def _media_from_metadata(metadata: dict | None, parsed_meta: dict) -> tuple[list[str], list[str], list[str]]:
    images: list[str] = []
    videos: list[str] = []
    audios: list[str] = []
    metadata = metadata or {}

    images_raw = metadata.get("images", "")
    if images_raw:
        images = [name.strip() for name in images_raw.split(",") if name.strip()]

    videos_raw = metadata.get("videos", "")
    if videos_raw:
        videos = [name.strip() for name in videos_raw.split(",") if name.strip()]

    audios_raw = metadata.get("audios", "")
    if audios_raw:
        audios = [name.strip() for name in audios_raw.split(",") if name.strip()]

    if not images and parsed_meta.get("images"):
        images = [
            name.strip()
            for name in parsed_meta["images"].split(",")
            if name.strip()
        ]
    if not videos and parsed_meta.get("videos"):
        videos = [
            name.strip()
            for name in parsed_meta["videos"].split(",")
            if name.strip()
        ]
    if not audios and parsed_meta.get("audios"):
        audios = [
            name.strip()
            for name in parsed_meta["audios"].split(",")
            if name.strip()
        ]

    return images, videos, audios


@app.get("/search")
def search_api(query: str = Query(..., description="Вопрос от студента")):
    normalized = normalize_query(query)
    if not is_meaningful_query(normalized):
        return _not_found_payload()

    try:
        total = collection.count()
    except Exception:
        total = 0
    if total <= 0:
        return _not_found_payload()

    prepared_query = f"query: {normalized}"
    query_embedding = model.encode(prepared_query).tolist()
    n_results = min(8, max(total, 1))

    results = collection.query(
        query_embeddings=[query_embedding],
        n_results=n_results,
        include=["documents", "distances", "metadatas"],
    )

    documents = (results.get("documents") or [[]])[0] or []
    distances = (results.get("distances") or [[]])[0] or []
    metadatas = (results.get("metadatas") or [[]])[0] or []

    if not documents:
        return _not_found_payload()

    best_raw = documents[0]
    best_distance = float(distances[0])
    best_clean, parsed_meta = extract_news_metadata(best_raw)
    best_clean = (best_clean or "").strip()

    if not best_clean or not is_relevant_match(normalized, best_clean, best_distance):
        return _not_found_payload()

    images, videos, audios = _media_from_metadata(
        metadatas[0] if metadatas else None,
        parsed_meta,
    )

    related_docs: list[str] = []
    related_distances: list[float] = []
    for index in range(1, len(documents)):
        clean_text, _ = extract_news_metadata(documents[index])
        clean_text = (clean_text or "").strip()
        if not clean_text:
            continue
        related_docs.append(clean_text)
        related_distances.append(float(distances[index]))

    related = build_related_items(related_docs, related_distances, best_clean)

    return {
        "status": "success",
        "found": True,
        "answer": best_clean,
        "distance": best_distance,
        "images": images,
        "videos": videos,
        "audios": audios,
        "related": related,
    }


@app.post("/upload/document")
async def upload_document(file: UploadFile = File(...)):
    file_path = os.path.join(data_dir, file.filename)
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    return {"status": "success", "filename": file.filename}


@app.post("/upload/media")
async def upload_media(file: UploadFile = File(...)):
    filename = file.filename.lower()

    if filename.endswith((".jpg", ".jpeg", ".png", ".svg")):
        target_dir = images_dir
    elif filename.endswith((".mp4", ".avi", ".mov", ".mkv")):
        target_dir = videos_dir
    elif filename.endswith((".mp3", ".wav")):
        target_dir = audios_dir
    else:
        return {"status": "error", "message": "Неподдерживаемый формат файла"}

    file_path = os.path.join(target_dir, file.filename)
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    return {"status": "success", "type": "media", "filename": file.filename}


def run_database_builder():
    print("Bilim Çeşmesi: Запуск автоматической пересборки ChromaDB...")
    result = build_database(base_dir, model=model, collection=collection)
    print(f"Bilim Çeşmesi: {result}")


@app.post("/build")
async def build_database_endpoint(
    background_tasks: BackgroundTasks,
    auto_backup: bool = True,
):
    backup_name: str | None = None
    if auto_backup:
        try:
            _close_chroma()
            try:
                backup_name = create_auto_backup(base_dir)
            finally:
                _open_chroma()
        except Exception as exc:
            try:
                _open_chroma()
            except Exception:
                pass
            raise HTTPException(
                status_code=500,
                detail=f"Awto-backup şowsuz: {exc}",
            ) from exc

    background_tasks.add_task(run_database_builder)
    return {
        "status": "started",
        "message": "Gözleg bazasy täzelenýär...",
        "backup": backup_name,
    }


class ParagraphUpdate(BaseModel):
    text: str
    images: list[str] = []
    videos: list[str] = []
    audios: list[str] = []
    is_news: bool = False
    news_preview: str | None = None
    news_order: int | None = None


class KbParagraphUpdate(BaseModel):
    source: str
    index: int
    text: str
    images: list[str] = []
    videos: list[str] = []
    audios: list[str] = []
    is_news: bool = False
    news_preview: str | None = None
    news_order: int | None = None


class KbSaveFileRequest(BaseModel):
    source: str
    paragraphs: list[ParagraphUpdate]


class KbMutateRequest(BaseModel):
    source: str
    index: int
    text: str | None = None


class KbExportRequest(BaseModel):
    paragraphs: list[ParagraphUpdate]


def _close_chroma() -> None:
    """Release Windows file locks held by PersistentClient before zip/rmtree."""
    global db_client, collection
    collection = None
    client = db_client
    db_client = None
    if client is not None:
        try:
            if hasattr(client, "clear_system_cache"):
                client.clear_system_cache()
        except Exception:
            pass
        del client
    gc.collect()
    time.sleep(0.35)


def _open_chroma() -> None:
    global db_client, collection
    db_client = chromadb.PersistentClient(path=chroma_path)
    collection = db_client.get_or_create_collection(name="tdbsi_history")


def _cleanup_temp(path: str) -> None:
    try:
        if path and os.path.isfile(path):
            os.remove(path)
    except OSError:
        pass


@app.get("/admin/db/export")
def admin_export_db():
    fd, temp_zip = tempfile.mkstemp(suffix=".zip", prefix="educore_export_")
    os.close(fd)
    try:
        _close_chroma()
        try:
            create_export_zip(base_dir, temp_zip)
        finally:
            _open_chroma()
    except Exception as exc:
        _cleanup_temp(temp_zip)
        raise HTTPException(
            status_code=500,
            detail=f"Eksport şowsuz: {exc}",
        ) from exc

    return FileResponse(
        temp_zip,
        filename="BilimCesmesi_DB_Export.zip",
        media_type="application/zip",
        background=BackgroundTask(_cleanup_temp, temp_zip),
    )


@app.post("/admin/db/import")
async def admin_import_db(file: UploadFile = File(...)):
    filename = (file.filename or "").lower()
    if not filename.endswith(".zip"):
        raise HTTPException(status_code=400, detail="Diňe .zip faýl goldanylýar.")

    fd, temp_zip = tempfile.mkstemp(suffix=".zip", prefix="educore_import_")
    os.close(fd)
    try:
        with open(temp_zip, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        _close_chroma()
        try:
            extracted = import_from_zip(base_dir, temp_zip)
        except ValueError as exc:
            _open_chroma()
            raise HTTPException(status_code=400, detail=str(exc)) from exc
        except Exception as exc:
            _open_chroma()
            raise HTTPException(
                status_code=500,
                detail=f"Import şowsuz: {exc}",
            ) from exc
        finally:
            _cleanup_temp(temp_zip)

        _open_chroma()
        return {
            "status": "success",
            "message": "Database imported successfully.",
            "files": extracted,
        }
    except HTTPException:
        raise
    except Exception as exc:
        _cleanup_temp(temp_zip)
        try:
            _open_chroma()
        except Exception:
            pass
        raise HTTPException(
            status_code=500,
            detail=f"Import şowsuz: {exc}",
        ) from exc

@app.post("/admin/parse-document")
async def admin_parse_document(file: UploadFile = File(...)):
    filename = file.filename or "document.docx"
    lower_name = filename.lower()
    if not lower_name.endswith((".docx", ".xlsx", ".txt")):
        raise HTTPException(
            status_code=400,
            detail="Diňe .docx, .xlsx we .txt faýllary goldanylýar.",
        )

    upload_path = os.path.join(
        drafts_dir(base_dir), f"_upload_{uuid.uuid4().hex}_{filename}"
    )
    with open(upload_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    try:
        draft = create_draft_from_file(base_dir, upload_path, filename)
    finally:
        if os.path.isfile(upload_path):
            os.remove(upload_path)

    return draft


@app.get("/admin/draft/{draft_id}")
def admin_get_draft(draft_id: str):
    try:
        return load_draft(base_dir, draft_id)
    except FileNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@app.put("/admin/draft/{draft_id}/paragraphs/{index}")
def admin_save_paragraph(draft_id: str, index: int, payload: ParagraphUpdate):
    try:
        return update_paragraph(base_dir, draft_id, index, payload.model_dump())
    except FileNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except IndexError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.post("/admin/draft/{draft_id}/finalize")
def admin_finalize_draft(draft_id: str):
    try:
        return finalize_draft(base_dir, draft_id)
    except FileNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.get("/admin/kb/paragraphs")
def admin_kb_list_paragraphs(
    q: str = Query("", alias="q"),
    news_only: bool = Query(False),
):
    try:
        return list_kb_paragraphs(base_dir, query=q, news_only=news_only)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@app.get("/admin/kb/stats")
def admin_kb_stats():
    try:
        return kb_stats(base_dir)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@app.put("/admin/kb/paragraphs")
def admin_kb_update_paragraph(payload: KbParagraphUpdate):
    try:
        return update_kb_paragraph(
            base_dir,
            payload.source,
            payload.index,
            payload.model_dump(),
        )
    except FileNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except IndexError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.post("/admin/kb/save")
def admin_kb_save_file(payload: KbSaveFileRequest):
    try:
        return save_kb_file(
            base_dir,
            payload.source,
            [item.model_dump() for item in payload.paragraphs],
        )
    except FileNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.post("/admin/kb/paragraphs/add")
def admin_kb_add_paragraph(payload: KbMutateRequest):
    try:
        return add_kb_paragraph(
            base_dir,
            payload.source,
            after_index=payload.index,
            text=payload.text or "Täze abzas",
        )
    except FileNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.post("/admin/kb/paragraphs/delete")
def admin_kb_delete_paragraph(payload: KbMutateRequest):
    try:
        return delete_kb_paragraph(base_dir, payload.source, payload.index)
    except FileNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except IndexError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.post("/admin/kb/paragraphs/duplicate")
def admin_kb_duplicate_paragraph(payload: KbMutateRequest):
    try:
        return duplicate_kb_paragraph(base_dir, payload.source, payload.index)
    except FileNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except IndexError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.post("/admin/kb/export-text")
def admin_kb_export_text(payload: KbExportRequest):
    try:
        text = export_paragraphs_text(
            [item.model_dump() for item in payload.paragraphs]
        )
        return {"status": "success", "text": text}
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


MAX_NEWS_ITEMS = 15


def _news_order_key(item: dict) -> tuple[int, int, int]:
    raw = item.get("news_order")
    try:
        order = int(raw)
        return (0, order, -int(item.get("_index", 0)))
    except (TypeError, ValueError):
        return (1, 0, -int(item.get("_index", 0)))


@app.get("/news")
def news_api():
    try:
        all_data = collection.get(include=["documents", "metadatas"])
    except Exception:
        return {"items": []}

    documents = all_data.get("documents") or []
    metadatas = all_data.get("metadatas") or []
    items: list[dict] = []

    for index, metadata in enumerate(metadatas):
        if not metadata or metadata.get("is_news") != "true":
            continue

        preview = (metadata.get("news_preview") or "").strip()
        if not preview:
            continue

        text = documents[index] if index < len(documents) else ""
        if not text:
            continue

        items.append(
            {
                "text": text,
                "preview": preview,
                "news_order": metadata.get("news_order"),
                "_index": index,
            }
        )

    items.sort(key=_news_order_key)
    items = items[:MAX_NEWS_ITEMS]
    return {
        "items": [
            {"text": item["text"], "preview": item["preview"]} for item in items
        ]
    }


if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8000)
