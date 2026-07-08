from beanie import Document
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime, timezone
from enum import Enum


class Urgency(str, Enum):
    low = "low"
    medium = "medium"
    high = "high"


class RequestStatus(str, Enum):
    open = "open"
    in_progress = "in_progress"
    done = "done"
    cancelled = "cancelled"


class GeoLocation(BaseModel):
    lat: float
    lng: float
    address: Optional[str] = None


class ServiceRequest(Document):
    client_id: str
    category_id: str
    title: str
    description: str
    photos: List[str] = []
    location: Optional[GeoLocation] = None
    urgency: Urgency = Urgency.medium
    status: RequestStatus = RequestStatus.open
    created_at: datetime = datetime.now(timezone.utc)
    updated_at: datetime = datetime.now(timezone.utc)

    class Settings:
        name = "service_requests"
        indexes = ["client_id", "status", "category_id"]
