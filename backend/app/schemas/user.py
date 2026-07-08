from pydantic import BaseModel, EmailStr
from typing import Optional, List
from datetime import datetime


class UserOut(BaseModel):
    id: str
    email: EmailStr
    full_name: str
    phone: Optional[str] = None
    role: str
    avatar_url: Optional[str] = None
    is_verified: bool
    is_active: bool
    created_at: datetime

    model_config = {"from_attributes": True}


class UserUpdate(BaseModel):
    full_name: Optional[str] = None
    phone: Optional[str] = None
    avatar_url: Optional[str] = None


class ProviderProfileOut(BaseModel):
    user_id: str
    bio: Optional[str] = None
    skills: List[str] = []
    categories: List[str] = []
    radius_km: float
    portfolio: List[str] = []
    avg_rating: float
    total_reviews: int
    is_verified_provider: bool

    model_config = {"from_attributes": True}


class ProviderProfileUpdate(BaseModel):
    bio: Optional[str] = None
    skills: Optional[List[str]] = None
    categories: Optional[List[str]] = None
    radius_km: Optional[float] = None
