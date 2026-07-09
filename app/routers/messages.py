from fastapi import APIRouter, Depends, HTTPException, status
from app.schemas.message import MessageSend, MessageEdit, ReactionToggle, RoomCreate, RoomOut
from app.services import message_service
from app.core.security import get_current_user
from app.utils.helpers import make_room_id

router = APIRouter()


@router.post("/room", response_model=RoomOut)
async def get_or_create_room(body: RoomCreate, current_user=Depends(get_current_user)):
    """Résout le room_id pour une demande et un correspondant.
    Le résultat est déterministe : appeler deux fois avec les mêmes paramètres
    renvoie toujours le même room_id.
    """
    room_id = make_room_id(body.request_id, str(current_user.id), body.other_user_id)
    return RoomOut(room_id=room_id)


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


@router.patch("/message/{message_id}")
async def edit_message(message_id: str, body: MessageEdit, current_user=Depends(get_current_user)):
    return await message_service.edit_message(message_id, body.content, current_user)


@router.delete("/message/{message_id}")
async def delete_message(message_id: str, current_user=Depends(get_current_user)):
    return await message_service.delete_message(message_id, current_user)


@router.post("/message/{message_id}/react")
async def react_to_message(message_id: str, body: ReactionToggle, current_user=Depends(get_current_user)):
    return await message_service.toggle_reaction(message_id, body.emoji, current_user)
