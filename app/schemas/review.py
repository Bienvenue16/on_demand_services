from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime
from app.schemas.common import PyObjectId


class ReviewCreate(BaseModel):
    request_id: str
    provider_id: str
    rating: int = Field(..., ge=1, le=5)
    comment: Optional[str] = None


class ReviewOut(BaseModel):
    id: PyObjectId
    request_id: PyObjectId
    reviewer_id: PyObjectId
    provider_id: PyObjectId
    rating: int
    comment: Optional[str]
    created_at: datetime

    model_config = {"from_attributes": True}
