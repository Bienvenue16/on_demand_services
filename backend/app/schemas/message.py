from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class MessageOut(BaseModel):
    id: str
    room_id: str
    sender_id: str
    content: str
    media_url: Optional[str] = None
    is_read: bool
    created_at: datetime

    model_config = {"from_attributes": True}


class MessageSend(BaseModel):
    content: str
    media_url: Optional[str] = None


class ConversationOut(BaseModel):
    room_id: str
    other_user_id: str
    last_message: Optional[MessageOut] = None
    unread_count: int = 0


class WSMessagePayload(BaseModel):
    type: str = "text"
    content: str
    media_url: Optional[str] = None
    room_id: str
    sender_id: str
    timestamp: str
