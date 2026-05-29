from beanie import Document
from pydantic import BaseModel
from typing import Optional, List, Dict, Any
from datetime import datetime, timezone
from enum import Enum


class ProviderValidationStatus(str, Enum):
    pending = "pending"           # En attente d'examen
    reviewing = "reviewing"       # En cours d'examen
    waiting_docs = "waiting_docs" # En attente de documents complémentaires
    approved = "approved"         # Validé
    rejected = "rejected"         # Refusé


class Location(BaseModel):
    lat: float
    lng: float
    city: Optional[str] = None
    address: Optional[str] = None


class ValidationHistoryEntry(BaseModel):
    status: str
    note: Optional[str] = None
    admin_id: str
    at: datetime = datetime.now(timezone.utc)


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
    # --- Workflow de validation admin ---
    validation_status: ProviderValidationStatus = ProviderValidationStatus.pending
    validation_notes: Optional[str] = None
    id_card_url: Optional[str] = None       # pièce d'identité uploadée
    validation_history: List[ValidationHistoryEntry] = []
    updated_at: datetime = datetime.now(timezone.utc)

    class Settings:
        name = "provider_profiles"
        indexes = ["user_id", "validation_status", "is_verified_provider"]
