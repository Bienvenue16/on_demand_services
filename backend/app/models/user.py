from beanie import Document
from pydantic import EmailStr
from typing import Optional
from datetime import datetime, timezone
from enum import Enum


class UserRole(str, Enum):
    client = "client"
    provider = "provider"
    admin = "admin"


class User(Document):
    email: EmailStr
    phone: Optional[str] = None
    hashed_password: str
    full_name: str
    role: UserRole = UserRole.client
    avatar_url: Optional[str] = None
    is_verified: bool = False
    is_active: bool = True
    refresh_token: Optional[str] = None
    verification_token: Optional[str] = None
    reset_token: Optional[str] = None
    created_at: datetime = datetime.now(timezone.utc)

    class Settings:
        name = "users"
        indexes = ["email", "phone"]
