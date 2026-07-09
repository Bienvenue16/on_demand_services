from pydantic import BaseModel
from typing import Optional, Dict, List
from datetime import datetime
from app.schemas.common import PyObjectId


class ReplyPreview(BaseModel):
    id: str
    sender_id: str
    content: str
    media_type: Optional[str] = None


class MessageOut(BaseModel):
    id: PyObjectId
    room_id: str
    sender_id: str
    content: str
    media_url: Optional[str] = None
    media_type: Optional[str] = None
    audio_duration_seconds: Optional[float] = None
    is_read: bool
    request_id: Optional[str] = None
    reply_to_id: Optional[str] = None
    reply_to: Optional[ReplyPreview] = None
    is_deleted: bool = False
    edited_at: Optional[datetime] = None
    reactions: Dict[str, List[str]] = {}
    created_at: datetime

    model_config = {"from_attributes": True}


class MessageSend(BaseModel):
    content: str
    media_url: Optional[str] = None
    media_type: Optional[str] = None
    audio_duration_seconds: Optional[float] = None
    request_id: Optional[str] = None   # requis pour la 1ère création d'une conversation
    reply_to_id: Optional[str] = None


class MessageEdit(BaseModel):
    content: str


class ReactionToggle(BaseModel):
    emoji: str


class RoomCreate(BaseModel):
    """Corps pour POST /messages/room — résout le room_id côté backend."""
    request_id: str
    other_user_id: str


class RoomOut(BaseModel):
    room_id: str


# ---------------------------------------------------------------------------
# Schémas de synthèse pour GET /messages/conversations
# ---------------------------------------------------------------------------

class OtherUserInfo(BaseModel):
    id: str
    full_name: str
    avatar_url: Optional[str] = None


class RequestInfo(BaseModel):
    id: str
    title: str
    status: Optional[str] = None
    client_id: Optional[str] = None


class LastMessageOut(BaseModel):
    id: str
    content: str
    sender_id: str
    created_at: datetime


class ConversationOut(BaseModel):
    room_id: str
    other_user: Optional[OtherUserInfo] = None
    request: Optional[RequestInfo] = None
    last_message: Optional[LastMessageOut] = None
    unread_count: int = 0


# ---------------------------------------------------------------------------
# Payload WebSocket sortant
# ---------------------------------------------------------------------------

class WSMessagePayload(BaseModel):
    type: str = "text"
    content: str
    media_url: Optional[str] = None
    media_type: Optional[str] = None
    audio_duration_seconds: Optional[float] = None
    reply_to: Optional[ReplyPreview] = None
    room_id: str
    sender_id: str
    message_id: str
    timestamp: str
