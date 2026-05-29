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
    # --- Gestion des bans ---
    is_banned: bool = False
    banned_reason: Optional[str] = None
    banned_at: Optional[datetime] = None
    banned_by: Optional[str] = None  # admin_id
    # --- Activité ---
    last_active: Optional[datetime] = None
    # --- Auth ---
    refresh_token: Optional[str] = None
    # Token précédent conservé pendant la fenêtre de tolérance (refresh concurrent)
    prev_refresh_token: Optional[str] = None
    refresh_token_rotated_at: Optional[datetime] = None
    verification_token: Optional[str] = None
    reset_token: Optional[str] = None
    created_at: datetime = datetime.now(timezone.utc)

    class Settings:
        name = "users"
        indexes = ["email", "phone", "is_banned", "role"]
