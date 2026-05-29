from fastapi import APIRouter, Depends
from app.services import notification_service
from app.core.security import get_current_user

router = APIRouter()


@router.get("")
async def list_notifications(page: int = 1, limit: int = 20, current_user=Depends(get_current_user)):
    return await notification_service.list_notifications(current_user, page, limit)


@router.get("/unread-count")
async def unread_count(current_user=Depends(get_current_user)):
    return await notification_service.unread_count(current_user)


@router.patch("/read-all")
async def mark_all_read(current_user=Depends(get_current_user)):
    return await notification_service.mark_all_read(current_user)


@router.patch("/{notif_id}/read")
async def mark_read(notif_id: str, current_user=Depends(get_current_user)):
    return await notification_service.mark_read(notif_id, current_user)
