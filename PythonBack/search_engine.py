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
from pydantic import BaseModel
from sentence_transformers import SentenceTransformer
import chromadb
import uvicorn

from database_builder import build_database, extract_news_metadata
from document_admin import (
    create_draft_from_file,
    drafts_dir,
    finalize_draft,
    load_draft,
    update_paragraph,
)

app = FastAPI(title="EduCore AI Reactive Engine")


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

for folder in [models_path, data_dir, images_dir, videos_dir, chroma_path]:
    os.makedirs(folder, exist_ok=True)

os.environ["SENTENCE_TRANSFORMERS_HOME"] = models_path
os.environ["HF_HOME"] = models_path
if _models_ready(models_path):
    os.environ["HF_HUB_OFFLINE"] = "1"
    os.environ["TRANSFORMERS_OFFLINE"] = "1"

print("EduCore: Инициализация ChromaDB...")
db_client = chromadb.PersistentClient(path=chroma_path)
collection = db_client.get_or_create_collection(name="tdbsi_history")

device = "cpu"
print(f"EduCore: Загрузка ИИ-модели на {device.upper()}... (Ждите, идет прогрев)")
model = SentenceTransformer("intfloat/multilingual-e5-base", device=device)
print("EduCore AI Микросервис успешно запущен и готов к работе!")


@app.get("/health")
def health_check():
    return {"status": "ok"}


@app.get("/search")
def search_api(query: str = Query(..., description="Вопрос от студента")):
    prepared_query = f"query: {query}"
    query_embedding = model.encode(prepared_query).tolist()

    results = collection.query(
        query_embeddings=[query_embedding],
        n_results=1,
        include=["documents", "distances", "metadatas"],
    )

    if results["documents"] and results["documents"][0]:
        found_text = results["documents"][0][0]
        distance = results["distances"][0][0]

        clean_text, parsed_meta = extract_news_metadata(found_text)
        found_text = clean_text

        images: list[str] = []
        videos: list[str] = []

        if results.get("metadatas") and results["metadatas"][0]:
            metadata = results["metadatas"][0][0] or {}

            images_raw = metadata.get("images", "")
            if images_raw:
                images = [name.strip() for name in images_raw.split(",") if name.strip()]

            videos_raw = metadata.get("videos", "")
            if videos_raw:
                videos = [name.strip() for name in videos_raw.split(",") if name.strip()]

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

        return {
            "status": "success",
            "answer": found_text,
            "distance": distance,
            "images": images,
            "videos": videos,
        }

    return {
        "status": "not_found",
        "answer": "Bagyşlaň, bu barada maglumat tapylmady.",
        "images": [],
        "videos": [],
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
    else:
        return {"status": "error", "message": "Неподдерживаемый формат файла"}

    file_path = os.path.join(target_dir, file.filename)
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    return {"status": "success", "type": "media", "filename": file.filename}


def run_database_builder():
    print("EduCore: Запуск автоматической пересборки ChromaDB...")
    result = build_database(base_dir, model=model, collection=collection)
    print(f"EduCore: {result}")


@app.post("/build")
async def build_database_endpoint(background_tasks: BackgroundTasks):
    background_tasks.add_task(run_database_builder)
    return {"status": "started", "message": "Gözleg bazasy täzelenýär..."}


class ParagraphUpdate(BaseModel):
    text: str
    images: list[str] = []
    videos: list[str] = []
    is_news: bool = False
    news_preview: str | None = None


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


MAX_NEWS_ITEMS = 15


@app.get("/news")
def news_api():
    try:
        all_data = collection.get(include=["documents", "metadatas"])
    except Exception:
        return {"items": []}

    documents = all_data.get("documents") or []
    metadatas = all_data.get("metadatas") or []
    items: list[dict[str, str]] = []

    for index, metadata in enumerate(metadatas):
        if not metadata or metadata.get("is_news") != "true":
            continue

        preview = (metadata.get("news_preview") or "").strip()
        if not preview:
            continue

        text = documents[index] if index < len(documents) else ""
        if not text:
            continue

        items.append({"text": text, "preview": preview})

    if len(items) > MAX_NEWS_ITEMS:
        items = items[-MAX_NEWS_ITEMS:]

    items.reverse()
    return {"items": items}


if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8000)
