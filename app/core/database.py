from motor.motor_asyncio import AsyncIOMotorClient
from beanie import init_beanie
from app.core.config import settings


async def init_db() -> None:
    client = AsyncIOMotorClient(settings.MONGODB_URL)
    from app.models import (
        User, ProviderProfile, ServiceRequest, Proposal,
        Message, Review, Notification, Category,
        Report, AuditLog, BlacklistedToken,
    )
    await init_beanie(
        database=client[settings.DB_NAME],
        document_models=[
            User, ProviderProfile, ServiceRequest, Proposal,
            Message, Review, Notification, Category,
            Report, AuditLog, BlacklistedToken,
        ],
    )
    await _ensure_super_admin(User)


async def _ensure_super_admin(User) -> None:
    """Crée le super admin défini dans .env s'il n'existe pas encore."""
    if not settings.SUPER_ADMIN_EMAIL or not settings.SUPER_ADMIN_PASSWORD:
        return

    from app.models.user import UserRole
    import bcrypt

    existing = await User.find_one(User.email == settings.SUPER_ADMIN_EMAIL)
    if existing:
        # Assure que le compte est bien admin même s'il a été modifié
        if existing.role != UserRole.admin:
            existing.role = UserRole.admin
            existing.is_verified = True
            existing.is_active = True
            await existing.save()
        return

    hashed = bcrypt.hashpw(
        settings.SUPER_ADMIN_PASSWORD.encode(), bcrypt.gensalt()
    ).decode()
    admin = User(
        email=settings.SUPER_ADMIN_EMAIL,
        hashed_password=hashed,
        full_name=settings.SUPER_ADMIN_NAME,
        role=UserRole.admin,
        is_verified=True,
        is_active=True,
    )
    await admin.insert()
    print(f"[startup] Super admin créé : {settings.SUPER_ADMIN_EMAIL}")
