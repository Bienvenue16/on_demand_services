from fastapi import APIRouter, Depends, UploadFile, File, Form
from app.services.file_service import save_upload, delete_file
from app.core.security import get_current_user

router = APIRouter()


@router.post("/image")
async def upload_image(
    file: UploadFile = File(...),
    file_type: str = Form("avatar"),
    current_user=Depends(get_current_user),
):
    url = await save_upload(file, file_type)
    return {"url": url}


@router.delete("/{filename:path}")
async def remove_file(filename: str, current_user=Depends(get_current_user)):
    return await delete_file(filename)
