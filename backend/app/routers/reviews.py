from fastapi import APIRouter, Depends
from app.schemas.review import ReviewCreate
from app.services import review_service
from app.core.security import get_current_user

router = APIRouter()


@router.post("", status_code=201)
async def create_review(body: ReviewCreate, current_user=Depends(get_current_user)):
    return await review_service.create(body, current_user)


@router.get("/provider/{provider_id}")
async def get_provider_reviews(provider_id: str, page: int = 1, limit: int = 20, current_user=Depends(get_current_user)):
    return await review_service.get_by_provider(provider_id, page, limit)


@router.delete("/{review_id}")
async def delete_review(review_id: str, current_user=Depends(get_current_user)):
    return await review_service.delete(review_id, current_user)
