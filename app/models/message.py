from beanie import Document
from typing import Optional, List
from datetime import datetime, timezone


class Message(Document):
    room_id: str
    sender_id: str
    content: str
    media_url: Optional[str] = None
    is_read: bool = False
    # Métadonnées conversation (remplis à la création)
    request_id: Optional[str] = None   # demande de service associée
    participants: List[str] = []        # [uid_a, uid_b] — permet le filtrage propre
    created_at: datetime = datetime.now(timezone.utc)

    class Settings:
        name = "messages"
        indexes = ["room_id", "sender_id", "participants", "request_id"]
