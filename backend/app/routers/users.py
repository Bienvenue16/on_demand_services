from fastapi import APIRouter, Depends
from app.schemas.user import UserOut, UserUpdate, ProviderProfileOut, ProviderProfileUpdate
from app.services import user_service
from app.core.security import get_current_user, get_provider_user

router = APIRouter()


@router.get("/me", response_model=UserOut)
async def get_me(current_user=Depends(get_current_user)):
    return await user_service.get_me(current_user)


@router.put("/me", response_model=UserOut)
async def update_me(body: UserUpdate, current_user=Depends(get_current_user)):
    return await user_service.update_me(current_user, body)


@router.delete("/me")
async def delete_me(current_user=Depends(get_current_user)):
    return await user_service.delete_me(current_user)


@router.get("/providers", response_model=dict)
async def list_providers(page: int = 1, limit: int = 20, current_user=Depends(get_current_user)):
    return await user_service.list_providers(page, limit)


@router.get("/providers/me", response_model=ProviderProfileOut)
async def get_my_provider_profile(current_user=Depends(get_provider_user)):
    return await user_service.get_provider_profile(str(current_user.id))


@router.put("/providers/me", response_model=ProviderProfileOut)
async def update_provider_profile(body: ProviderProfileUpdate, current_user=Depends(get_provider_user)):
    return await user_service.update_provider(current_user, body)


@router.get("/providers/{user_id}", response_model=ProviderProfileOut)
async def get_provider(user_id: str, current_user=Depends(get_current_user)):
    return await user_service.get_provider(user_id)


@router.get("/{user_id}", response_model=UserOut)
async def get_user(user_id: str, current_user=Depends(get_current_user)):
    return await user_service.get_user(user_id)
