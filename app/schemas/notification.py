from pydantic import BaseModel
from typing import Optional
from datetime import datetime
from app.schemas.common import PyObjectId


class NotificationOut(BaseModel):
    id: PyObjectId
    user_id: PyObjectId
    type: str
    title: str
    body: str
    is_read: bool
    ref_id: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": True}
