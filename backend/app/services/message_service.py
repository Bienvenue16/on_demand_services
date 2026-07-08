from app.models.message import Message
from app.models.user import User
from app.schemas.message import MessageSend
from app.utils.pagination import paginate
from typing import Optional


async def get_conversations(user: User) -> list:
    user_id = str(user.id)
    all_messages = await Message.find().sort(-Message.created_at).to_list()
    seen: dict = {}
    for msg in all_messages:
        if msg.room_id not in seen and (msg.sender_id == user_id or user_id in msg.room_id):
            seen[msg.room_id] = msg
    return list(seen.values())


async def get_history(room_id: str, page: int = 1, limit: int = 50) -> dict:
    query = Message.find(Message.room_id == room_id).sort(-Message.created_at)
    return await paginate(query, page, limit)


async def send(room_id: str, body: MessageSend, user: User) -> Message:
    msg = Message(
        room_id=room_id,
        sender_id=str(user.id),
        content=body.content,
        media_url=body.media_url,
    )
    await msg.insert()
    return msg


async def mark_read(room_id: str, user: User) -> dict:
    await Message.find(
        Message.room_id == room_id,
        Message.sender_id != str(user.id),
        Message.is_read == False,
    ).update({"$set": {"is_read": True}})
    return {"message": "Messages marqués comme lus"}


async def save_message(room_id: str, sender_id: str, content: str, media_url: Optional[str] = None) -> Message:
    """Utilisée par le handler WebSocket pour persister les messages."""
    msg = Message(room_id=room_id, sender_id=sender_id, content=content, media_url=media_url)
    await msg.insert()
    return msg
