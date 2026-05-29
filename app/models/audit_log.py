from beanie import Document
from typing import Optional, Any, Dict
from datetime import datetime, timezone


class AuditLog(Document):
    admin_id: str
    admin_email: str
    action: str                        # ex: "ban_user", "validate_provider", "delete_review"
    target_type: Optional[str] = None  # ex: "user", "review", "report"
    target_id: Optional[str] = None
    detail: Optional[Dict[str, Any]] = None  # données contextuelles libres
    ip_address: Optional[str] = None
    created_at: datetime = datetime.now(timezone.utc)

    class Settings:
        name = "audit_logs"
        indexes = ["admin_id", "action", "created_at"]
