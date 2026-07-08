from datetime import datetime, timezone
from app.websocket.manager import ConnectionManager
from app.services.message_service import save_message


async def handle_message(room_id: str, user, data: dict, manager: ConnectionManager) -> None:
    content = data.get("content", "")
    media_url = data.get("media_url")

    if not content and not media_url:
        return

    msg = await save_message(room_id, str(user.id), content, media_url)

    payload = {
        "type": data.get("type", "text"),
        "content": content,
        "media_url": media_url,
        "room_id": room_id,
        "sender_id": str(user.id),
        "message_id": str(msg.id),
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    await manager.send_to_room(room_id, payload)
