from beanie import Document
from typing import Optional
from datetime import datetime, timezone


class Message(Document):
    room_id: str
    sender_id: str
    content: str
    media_url: Optional[str] = None
    is_read: bool = False
    created_at: datetime = datetime.now(timezone.utc)

    class Settings:
        name = "messages"
        indexes = ["room_id", "sender_id"]
