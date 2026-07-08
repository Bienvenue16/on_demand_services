from datetime import datetime, timezone
from typing import Optional

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
        last_message = LastMessageOut(
            id=str(last_msg_doc["_id"]),
            content=last_msg_doc.get("content", ""),
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


async def get_history(room_id: str, page: int = 1, limit: int = 50) -> dict:
    query = Message.find(Message.room_id == room_id).sort(-Message.created_at)
    return await paginate(query, page, limit)


async def send(room_id: str, body: MessageSend, user: User) -> Message:
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
        request_id=body.request_id,
        participants=participants,
    )
    await msg.insert()

    # Diffuse en temps reel aux clients connectes sur ce salon (ex: envoi via REST
    # pendant que l'autre participant est connecte en WebSocket). L'expediteur
    # est exclu : il a deja son message localement via la reponse de cet appel.
    await manager.send_to_room(
        room_id,
        {
            "type": "text",
            "content": msg.content,
            "media_url": msg.media_url,
            "room_id": room_id,
            "sender_id": str(user.id),
            "message_id": str(msg.id),
            "timestamp": msg.created_at.isoformat(),
        },
        exclude_user_id=str(user.id),
    )

    return msg


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


async def save_message(
    room_id: str,
    sender_id: str,
    content: str,
    media_url: Optional[str] = None,
    request_id: Optional[str] = None,
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
        request_id=request_id,
        participants=participants,
    )
    await msg.insert()
    return msg
