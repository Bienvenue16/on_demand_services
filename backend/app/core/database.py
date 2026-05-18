from motor.motor_asyncio import AsyncIOMotorClient
from beanie import init_beanie
from app.core.config import settings


async def init_db() -> None:
    client = AsyncIOMotorClient(settings.MONGODB_URL)
    from app.models import (
        User, ProviderProfile, ServiceRequest, Proposal,
        Message, Review, Notification, Category,
    )
    await init_beanie(
        database=client[settings.DB_NAME],
        document_models=[
            User, ProviderProfile, ServiceRequest, Proposal,
            Message, Review, Notification, Category,
        ],
    )
