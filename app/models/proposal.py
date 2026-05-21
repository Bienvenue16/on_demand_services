from beanie import Document
from typing import Optional
from datetime import datetime, timezone
from enum import Enum


class ProposalStatus(str, Enum):
    pending = "pending"
    accepted = "accepted"
    declined = "declined"


class Proposal(Document):
    request_id: str
    provider_id: str
    message: str
    price_estimate: Optional[float] = None
    status: ProposalStatus = ProposalStatus.pending
    created_at: datetime = datetime.now(timezone.utc)

    class Settings:
        name = "proposals"
        indexes = ["request_id", "provider_id"]
