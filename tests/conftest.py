import pytest_asyncio
from beanie import init_beanie
from httpx import AsyncClient, ASGITransport
from motor.motor_asyncio import AsyncIOMotorClient

from app.core.config import settings
from app.main import app


@pytest_asyncio.fixture(autouse=True)
async def _init_test_db():
    """Initialise Beanie sur une base MongoDB dédiée aux tests (ne touche jamais la base de dev/prod)."""
    from app.models import (
        User, ProviderProfile, ServiceRequest, Proposal,
        Message, Review, Notification, Category,
        Report, AuditLog, BlacklistedToken,
    )

    test_client = AsyncIOMotorClient(settings.MONGODB_URL)
    await init_beanie(
        database=test_client[f"{settings.DB_NAME}_test"],
        document_models=[
            User, ProviderProfile, ServiceRequest, Proposal,
            Message, Review, Notification, Category,
            Report, AuditLog, BlacklistedToken,
        ],
    )
    yield
    test_client.close()


@pytest_asyncio.fixture
async def client():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        yield ac
