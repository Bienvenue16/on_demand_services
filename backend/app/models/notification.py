from beanie import Document
from typing import Optional
from datetime import datetime, timezone


class Notification(Document):
    user_id: str
    type: str
    title: str
    body: str
    is_read: bool = False
    ref_id: Optional[str] = None
    created_at: datetime = datetime.now(timezone.utc)

    class Settings:
        name = "notifications"
        indexes = ["user_id", "is_read"]
