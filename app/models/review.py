from beanie import Document
from pydantic import Field
from typing import Optional
from datetime import datetime, timezone


class Review(Document):
    request_id: str
    reviewer_id: str
    provider_id: str
    rating: int = Field(..., ge=1, le=5)
    comment: Optional[str] = None
    created_at: datetime = datetime.now(timezone.utc)

    class Settings:
        name = "reviews"
        indexes = ["provider_id", "reviewer_id"]
