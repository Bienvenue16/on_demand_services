from datetime import datetime, timezone
from app.websocket.manager import ConnectionManager
from app.services.message_service import save_message, _reply_preview


async def handle_message(room_id: str, user, data: dict, manager: ConnectionManager) -> None:
    msg_type = data.get("type", "text")

    if msg_type == "typing":
        # Relais volatile, non persiste : signale a l'autre participant que l'utilisateur ecrit.
        await manager.send_to_room(
            room_id,
            {
                "type": "typing",
                "room_id": room_id,
                "sender_id": str(user.id),
                "is_typing": bool(data.get("is_typing", True)),
            },
            exclude_user_id=str(user.id),
        )
        return

    content = data.get("content", "")
    media_url = data.get("media_url")
    media_type = data.get("media_type")
    audio_duration_seconds = data.get("audio_duration_seconds")
    reply_to_id = data.get("reply_to_id")
    request_id = data.get("request_id")   # transmis par le client lors du 1er message de la salle

    if not content and not media_url:
        return

    msg = await save_message(
        room_id, str(user.id), content, media_url, request_id,
        media_type=media_type,
        audio_duration_seconds=audio_duration_seconds,
        reply_to_id=reply_to_id,
    )
    reply_preview = await _reply_preview(reply_to_id)

    payload = {
        "type": data.get("type", "text"),
        "content": content,
        "media_url": media_url,
        "media_type": media_type,
        "audio_duration_seconds": audio_duration_seconds,
        "reply_to": reply_preview,
        "room_id": room_id,
        "sender_id": str(user.id),
        "message_id": str(msg.id),
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    await manager.send_to_room(room_id, payload, exclude_user_id=str(user.id))
