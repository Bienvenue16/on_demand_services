from fastapi import APIRouter, Depends
from app.schemas.message import MessageSend
from app.services import message_service
from app.core.security import get_current_user

router = APIRouter()


@router.get("/conversations")
async def get_conversations(current_user=Depends(get_current_user)):
    return await message_service.get_conversations(current_user)


@router.get("/{room_id}/history")
async def get_history(room_id: str, page: int = 1, limit: int = 50, current_user=Depends(get_current_user)):
    return await message_service.get_history(room_id, page, limit)


@router.post("/{room_id}", status_code=201)
async def send_message(room_id: str, body: MessageSend, current_user=Depends(get_current_user)):
    return await message_service.send(room_id, body, current_user)


@router.patch("/{room_id}/read")
async def mark_read(room_id: str, current_user=Depends(get_current_user)):
    return await message_service.mark_read(room_id, current_user)
