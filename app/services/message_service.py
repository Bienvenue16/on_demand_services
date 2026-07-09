from datetime import datetime, timezone
from typing import Optional

from fastapi import HTTPException, status
from fastapi.encoders import jsonable_encoder

from app.models.message import Message
from app.models.user import User
from app.models.service_request import ServiceRequest
from app.schemas.message import (
    MessageSend, ConversationOut, OtherUserInfo, RequestInfo, LastMessageOut,
)
from app.utils.helpers import parse_room_id
from app.utils.pagination import paginate
from app.websocket.manager import manager


async def get_conversations(user: User) -> list[ConversationOut]:
    """Retourne la liste des conversations de l'utilisateur avec infos de synthèse."""
    user_id = str(user.id)

    # Aggregation MongoDB : groupe par room_id, garde le dernier message de chaque salle
    # Ne remonte que les salles où l'utilisateur est participant
    collection = Message.get_motor_collection()
    pipeline = [
        {"$match": {"participants": user_id}},
        {"$sort": {"created_at": -1}},
        {"$group": {
            "_id": "$room_id",
            "last_msg": {"$first": "$$ROOT"},
            "request_id": {"$first": "$request_id"},
            "participants": {"$first": "$participants"},
        }},
        {"$sort": {"last_msg.created_at": -1}},
    ]
    groups = await collection.aggregate(pipeline).to_list(length=200)

    results: list[ConversationOut] = []
    for g in groups:
        room_id: str = g["_id"]
        participants: list = g.get("participants", [])
        request_id: Optional[str] = g.get("request_id")
        last_msg_doc: dict = g["last_msg"]

        # Correspondant
        other_user_id = next((p for p in participants if p != user_id), None)
        other_user: Optional[OtherUserInfo] = None
        if other_user_id:
            ou = await User.get(other_user_id)
            if ou:
                other_user = OtherUserInfo(
                    id=str(ou.id),
                    full_name=ou.full_name,
                    avatar_url=ou.avatar_url,
                )

        # Demande liée
        request_info: Optional[RequestInfo] = None
        if request_id:
            req = await ServiceRequest.get(request_id)
            if req:
                request_info = RequestInfo(
                    id=str(req.id),
                    title=req.title,
                    status=req.status.value,
                    client_id=req.client_id,
                )

        # Dernier message
        last_msg_content = last_msg_doc.get("content", "")
        if last_msg_doc.get("is_deleted"):
            last_msg_content = "Message supprimé"
        elif not last_msg_content and last_msg_doc.get("media_type") == "audio":
            last_msg_content = "🎤 Message vocal"
        elif not last_msg_content and last_msg_doc.get("media_url"):
            last_msg_content = "📷 Photo"

        last_message = LastMessageOut(
            id=str(last_msg_doc["_id"]),
            content=last_msg_content,
            sender_id=last_msg_doc.get("sender_id", ""),
            created_at=last_msg_doc.get("created_at", datetime.now(timezone.utc)),
        )

        # Non lus : messages de la salle envoyés par l'autre
        unread_count = await Message.find(
            Message.room_id == room_id,
            Message.sender_id != user_id,
            Message.is_read == False,
        ).count()

        results.append(ConversationOut(
            room_id=room_id,
            other_user=other_user,
            request=request_info,
            last_message=last_message,
            unread_count=unread_count,
        ))

    return results


async def _reply_preview(reply_to_id: Optional[str]) -> Optional[dict]:
    if not reply_to_id:
        return None
    replied = await Message.get(reply_to_id)
    if not replied:
        return None
    return {
        "id": str(replied.id),
        "sender_id": replied.sender_id,
        "content": "Message supprimé" if replied.is_deleted else replied.content,
        "media_type": replied.media_type,
    }


async def get_history(room_id: str, page: int = 1, limit: int = 50) -> dict:
    query = Message.find(Message.room_id == room_id).sort(-Message.created_at)
    result = await paginate(query, page, limit)

    data = []
    for m in result["data"]:
        item = jsonable_encoder(m)
        reply_preview = await _reply_preview(m.reply_to_id)
        if reply_preview:
            item["reply_to"] = reply_preview
        data.append(item)
    result["data"] = data
    return result


async def send(room_id: str, body: MessageSend, user: User) -> dict:
    # Extrait les participants depuis le room_id
    try:
        _, uid_a, uid_b = parse_room_id(room_id)
        participants = [uid_a, uid_b]
    except ValueError:
        participants = [str(user.id)]

    msg = Message(
        room_id=room_id,
        sender_id=str(user.id),
        content=body.content,
        media_url=body.media_url,
        media_type=body.media_type,
        audio_duration_seconds=body.audio_duration_seconds,
        request_id=body.request_id,
        reply_to_id=body.reply_to_id,
        participants=participants,
    )
    await msg.insert()

    reply_preview = await _reply_preview(body.reply_to_id)

    # Diffuse en temps reel aux clients connectes sur ce salon (ex: envoi via REST
    # pendant que l'autre participant est connecte en WebSocket). L'expediteur
    # est exclu : il a deja son message localement via la reponse de cet appel.
    await manager.send_to_room(
        room_id,
        {
            "type": "text",
            "content": msg.content,
            "media_url": msg.media_url,
            "media_type": msg.media_type,
            "audio_duration_seconds": msg.audio_duration_seconds,
            "reply_to": reply_preview,
            "room_id": room_id,
            "sender_id": str(user.id),
            "message_id": str(msg.id),
            "timestamp": msg.created_at.isoformat(),
        },
        exclude_user_id=str(user.id),
    )

    result = jsonable_encoder(msg)
    if reply_preview:
        result["reply_to"] = reply_preview
    return result


async def mark_read(room_id: str, user: User) -> dict:
    await Message.find(
        Message.room_id == room_id,
        Message.sender_id != str(user.id),
        Message.is_read == False,
    ).update({"$set": {"is_read": True}})

    # Notifie en temps reel l'autre participant que ses messages ont ete lus (accuse de lecture).
    await manager.send_to_room(
        room_id,
        {
            "type": "read",
            "room_id": room_id,
            "reader_id": str(user.id),
        },
        exclude_user_id=str(user.id),
    )

    return {"message": "Messages marqués comme lus"}


async def edit_message(message_id: str, content: str, user: User) -> Message:
    msg = await Message.get(message_id)
    if not msg:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Message introuvable")
    if msg.sender_id != str(user.id):
        raise HTTPException(status.HTTP_403_FORBIDDEN, detail="Non autorisé")
    if msg.is_deleted:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="Message supprimé")

    msg.content = content
    msg.edited_at = datetime.now(timezone.utc)
    await msg.save()

    await manager.send_to_room(
        msg.room_id,
        {
            "type": "message_edited",
            "room_id": msg.room_id,
            "message_id": str(msg.id),
            "content": msg.content,
            "edited_at": msg.edited_at.isoformat(),
        },
        exclude_user_id=str(user.id),
    )
    return msg


async def delete_message(message_id: str, user: User) -> Message:
    msg = await Message.get(message_id)
    if not msg:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Message introuvable")
    if msg.sender_id != str(user.id):
        raise HTTPException(status.HTTP_403_FORBIDDEN, detail="Non autorisé")

    msg.is_deleted = True
    msg.content = ""
    msg.media_url = None
    msg.media_type = None
    msg.audio_duration_seconds = None
    await msg.save()

    await manager.send_to_room(
        msg.room_id,
        {
            "type": "message_deleted",
            "room_id": msg.room_id,
            "message_id": str(msg.id),
        },
        exclude_user_id=str(user.id),
    )
    return msg


async def toggle_reaction(message_id: str, emoji: str, user: User) -> Message:
    msg = await Message.get(message_id)
    if not msg:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Message introuvable")

    user_id = str(user.id)
    users_for_emoji = msg.reactions.get(emoji, [])
    if user_id in users_for_emoji:
        users_for_emoji = [u for u in users_for_emoji if u != user_id]
    else:
        users_for_emoji = [*users_for_emoji, user_id]

    if users_for_emoji:
        msg.reactions[emoji] = users_for_emoji
    else:
        msg.reactions.pop(emoji, None)

    await msg.save()

    await manager.send_to_room(
        msg.room_id,
        {
            "type": "reaction_updated",
            "room_id": msg.room_id,
            "message_id": str(msg.id),
            "reactions": msg.reactions,
        },
        exclude_user_id=user_id,
    )
    return msg


async def save_message(
    room_id: str,
    sender_id: str,
    content: str,
    media_url: Optional[str] = None,
    request_id: Optional[str] = None,
    media_type: Optional[str] = None,
    audio_duration_seconds: Optional[float] = None,
    reply_to_id: Optional[str] = None,
) -> Message:
    """Utilisée par le handler WebSocket pour persister les messages."""
    try:
        _, uid_a, uid_b = parse_room_id(room_id)
        participants = [uid_a, uid_b]
    except ValueError:
        participants = [sender_id]

    msg = Message(
        room_id=room_id,
        sender_id=sender_id,
        content=content,
        media_url=media_url,
        media_type=media_type,
        audio_duration_seconds=audio_duration_seconds,
        request_id=request_id,
        reply_to_id=reply_to_id,
        participants=participants,
    )
    await msg.insert()
    return msg
