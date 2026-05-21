from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from app.schemas.common import PyObjectId


class GeoLocationIn(BaseModel):
    lat: float
    lng: float
    address: Optional[str] = None


class ServiceRequestCreate(BaseModel):
    category_id: str
    title: str
    description: str
    photos: List[str] = []
    location: Optional[GeoLocationIn] = None
    urgency: str = "medium"


class ServiceRequestOut(BaseModel):
    id: PyObjectId
    client_id: PyObjectId
    category_id: PyObjectId
    title: str
    description: str
    photos: List[str]
    urgency: str
    status: str
    created_at: datetime

    model_config = {"from_attributes": True}


class ServiceRequestUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    photos: Optional[List[str]] = None
    location: Optional[GeoLocationIn] = None
    urgency: Optional[str] = None


class StatusUpdate(BaseModel):
    status: str
