from beanie import Document
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime, timezone
from enum import Enum


class ReportType(str, Enum):
    message = "message"
    review = "review"
    service_request = "service_request"
    user = "user"


class ReportStatus(str, Enum):
    pending = "pending"
    reviewing = "reviewing"
    resolved = "resolved"
    dismissed = "dismissed"


class ReportSeverity(str, Enum):
    low = "low"
    medium = "medium"
    high = "high"


class ModerationAction(BaseModel):
    admin_id: str
    action: str
    note: Optional[str] = None
    at: datetime = datetime.now(timezone.utc)


class Report(Document):
    reporter_id: str
    target_type: ReportType
    target_id: str
    reason: str
    description: Optional[str] = None
    severity: ReportSeverity = ReportSeverity.medium
    status: ReportStatus = ReportStatus.pending
    moderation_history: List[ModerationAction] = []
    resolved_by: Optional[str] = None
    created_at: datetime = datetime.now(timezone.utc)
    updated_at: datetime = datetime.now(timezone.utc)

    class Settings:
        name = "reports"
        indexes = ["reporter_id", "target_id", "status", "severity"]
