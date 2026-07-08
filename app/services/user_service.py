from datetime import datetime, timezone
from fastapi import HTTPException, status
from app.models.user import User
from app.models.provider_profile import ProviderProfile, Location
from app.schemas.user import UserUpdate, ProviderProfileUpdate
from app.schemas.common import MessageResponse
from app.utils.pagination import paginate


async def get_me(user: User) -> User:
    return user


async def update_me(user: User, body: UserUpdate) -> User:
    data = body.model_dump(exclude_none=True)
    for key, value in data.items():
        setattr(user, key, value)
    await user.save()
    return user


async def delete_me(user: User) -> MessageResponse:
    user.is_active = False
    await user.save()
    return MessageResponse(message="Compte désactivé")


async def get_user(user_id: str) -> User:
    user = await User.get(user_id)
    if not user:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Utilisateur introuvable")
    return user


async def list_providers(page: int = 1, limit: int = 20) -> dict:
    query = User.find(User.role == "provider", User.is_active == True)
    return await paginate(query, page, limit)


async def get_provider_profile(user_id: str) -> ProviderProfile:
    profile = await ProviderProfile.find_one(ProviderProfile.user_id == user_id)
    if not profile:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Profil prestataire introuvable")
    return profile


async def get_provider(user_id: str) -> ProviderProfile:
    return await get_provider_profile(user_id)


async def update_provider(user: User, body: ProviderProfileUpdate) -> ProviderProfile:
    profile = await ProviderProfile.find_one(ProviderProfile.user_id == str(user.id))
    if not profile:
        profile = ProviderProfile(user_id=str(user.id))
    data = body.model_dump(exclude_none=True)
    if "location" in data:
        data["location"] = Location(**data["location"])
    for key, value in data.items():
        setattr(profile, key, value)
    profile.updated_at = datetime.now(timezone.utc)
    await profile.save()
    return profile
