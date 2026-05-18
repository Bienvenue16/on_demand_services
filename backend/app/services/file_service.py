import aiofiles
import uuid
import os
from fastapi import UploadFile, HTTPException
from app.core.config import settings

ALLOWED_TYPES = {"image/jpeg", "image/png", "image/webp"}
FOLDERS = {
    "avatar": "avatars",
    "portfolio": "portfolio",
    "request": "requests",
    "message": "messages",
    "certificate": "certificates",
}


async def save_upload(file: UploadFile, file_type: str) -> str:
    if file.content_type not in ALLOWED_TYPES:
        raise HTTPException(400, detail=f"Type non autorisé. Acceptés : jpeg, png, webp")
    content = await file.read()
    max_bytes = settings.MAX_FILE_SIZE_MB * 1024 * 1024
    if len(content) > max_bytes:
        raise HTTPException(400, detail=f"Fichier trop lourd (max {settings.MAX_FILE_SIZE_MB} Mo)")
    folder = FOLDERS.get(file_type, "avatars")
    ext = (file.filename or "file.jpg").rsplit(".", 1)[-1].lower()
    filename = f"{uuid.uuid4().hex}.{ext}"
    path = os.path.join(settings.UPLOAD_DIR, folder, filename)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    async with aiofiles.open(path, "wb") as f:
        await f.write(content)
    return f"{settings.STATIC_URL}/{folder}/{filename}"


async def delete_file(relative_path: str) -> dict:
    safe_path = relative_path.lstrip("/").replace("..", "")
    full_path = os.path.join(settings.UPLOAD_DIR, safe_path)
    if os.path.isfile(full_path):
        os.remove(full_path)
    return {"message": "Fichier supprimé"}
