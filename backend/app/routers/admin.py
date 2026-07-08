from fastapi import APIRouter, Depends, HTTPException, status
from app.models.user import User
from app.models.provider_profile import ProviderProfile
from app.models.category import Category
from app.schemas.category import CategoryCreate
from app.schemas.common import MessageResponse
from app.core.security import get_admin_user
from app.utils.pagination import paginate

router = APIRouter()


@router.get("/users")
async def list_all_users(page: int = 1, limit: int = 20, admin=Depends(get_admin_user)):
    return await paginate(User.find(), page, limit)


@router.post("/users/{user_id}/ban", response_model=MessageResponse)
async def ban_user(user_id: str, admin=Depends(get_admin_user)):
    user = await User.get(user_id)
    if not user:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Utilisateur introuvable")
    user.is_active = False
    await user.save()
    return MessageResponse(message="Utilisateur banni")


@router.post("/providers/{user_id}/verify", response_model=MessageResponse)
async def verify_provider(user_id: str, admin=Depends(get_admin_user)):
    profile = await ProviderProfile.find_one(ProviderProfile.user_id == user_id)
    if not profile:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Profil prestataire introuvable")
    profile.is_verified_provider = True
    await profile.save()
    return MessageResponse(message="Prestataire vérifié")


@router.get("/stats")
async def get_stats(admin=Depends(get_admin_user)):
    total_users = await User.count()
    total_providers = await User.find(User.role == "provider").count()
    total_clients = await User.find(User.role == "client").count()
    return {"total_users": total_users, "total_providers": total_providers, "total_clients": total_clients}


@router.post("/categories", status_code=201)
async def create_category(body: CategoryCreate, admin=Depends(get_admin_user)):
    cat = Category(**body.model_dump())
    await cat.insert()
    return cat


@router.delete("/categories/{category_id}", response_model=MessageResponse)
async def delete_category(category_id: str, admin=Depends(get_admin_user)):
    cat = await Category.get(category_id)
    if not cat:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Catégorie introuvable")
    await cat.delete()
    return MessageResponse(message="Catégorie supprimée")
