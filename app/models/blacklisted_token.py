from beanie import Document
from datetime import datetime, timezone


class BlacklistedToken(Document):
    token: str
    user_id: str
    blacklisted_at: datetime = datetime.now(timezone.utc)
    expires_at: datetime  # pour nettoyer automatiquement les tokens expirés

    class Settings:
        name = "blacklisted_tokens"
        indexes = ["token", "user_id", "expires_at"]
