from fastapi import APIRouter, HTTPException, status
from app.models.category import Category

router = APIRouter()


@router.get("")
async def list_categories():
    return await Category.find(Category.is_active == True).to_list()


@router.get("/{category_id}")
async def get_category(category_id: str):
    cat = await Category.get(category_id)
    if not cat:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Catégorie introuvable")
    return cat
