from fastapi import HTTPException, status
from app.models.review import Review
from app.models.provider_profile import ProviderProfile
from app.models.user import User
from app.schemas.review import ReviewCreate
from app.schemas.common import MessageResponse
from app.utils.pagination import paginate


async def create(body: ReviewCreate, user: User) -> Review:
    existing = await Review.find_one(
        Review.request_id == body.request_id,
        Review.reviewer_id == str(user.id),
    )
    if existing:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="Vous avez déjà noté cette prestation")
    review = Review(reviewer_id=str(user.id), **body.model_dump())
    await review.insert()
    await _update_avg_rating(body.provider_id)
    return review


async def get_by_provider(provider_id: str, page: int = 1, limit: int = 20) -> dict:
    query = Review.find(Review.provider_id == provider_id).sort(-Review.created_at)
    return await paginate(query, page, limit)


async def delete(review_id: str, user: User) -> MessageResponse:
    review = await Review.get(review_id)
    if not review:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Avis introuvable")
    if review.reviewer_id != str(user.id):
        raise HTTPException(status.HTTP_403_FORBIDDEN, detail="Non autorisé")
    provider_id = review.provider_id
    await review.delete()
    await _update_avg_rating(provider_id)
    return MessageResponse(message="Avis supprimé")


async def _update_avg_rating(provider_id: str) -> None:
    reviews = await Review.find(Review.provider_id == provider_id).to_list()
    profile = await ProviderProfile.find_one(ProviderProfile.user_id == provider_id)
    if not profile:
        return
    if reviews:
        profile.avg_rating = round(sum(r.rating for r in reviews) / len(reviews), 2)
        profile.total_reviews = len(reviews)
    else:
        profile.avg_rating = 0.0
        profile.total_reviews = 0
    await profile.save()
