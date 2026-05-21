from beanie import Document
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime, timezone


class Location(BaseModel):
    lat: float
    lng: float
    city: Optional[str] = None
    address: Optional[str] = None


class ProviderProfile(Document):
    user_id: str
    bio: Optional[str] = None
    skills: List[str] = []
    categories: List[str] = []
    location: Optional[Location] = None
    radius_km: float = 20.0
    portfolio: List[str] = []
    certificates: List[str] = []
    avg_rating: float = 0.0
    total_reviews: int = 0
    is_verified_provider: bool = False
    updated_at: datetime = datetime.now(timezone.utc)

    class Settings:
        name = "provider_profiles"
        indexes = ["user_id"]
