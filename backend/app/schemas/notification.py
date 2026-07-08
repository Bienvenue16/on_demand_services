from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class NotificationOut(BaseModel):
    id: str
    user_id: str
    type: str
    title: str
    body: str
    is_read: bool
    ref_id: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": True}
