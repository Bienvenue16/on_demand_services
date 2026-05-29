from typing import Optional
from app.models.notification import Notification
from app.models.user import User
from app.schemas.common import MessageResponse
from app.utils.pagination import paginate


async def create_notification(
    user_id: str,
    type: str,
    title: str,
    body: str,
    ref_id: Optional[str] = None,
) -> Notification:
    notif = Notification(user_id=user_id, type=type, title=title, body=body, ref_id=ref_id)
    await notif.insert()
    return notif


async def list_notifications(user: User, page: int = 1, limit: int = 20) -> dict:
    query = Notification.find(Notification.user_id == str(user.id)).sort(-Notification.created_at)
    return await paginate(query, page, limit)


async def mark_read(notif_id: str, user: User) -> MessageResponse:
    notif = await Notification.get(notif_id)
    if notif and notif.user_id == str(user.id):
        notif.is_read = True
        await notif.save()
    return MessageResponse(message="Notification marquée comme lue")


async def mark_all_read(user: User) -> MessageResponse:
    await Notification.find(
        Notification.user_id == str(user.id),
        Notification.is_read == False,
    ).update({"$set": {"is_read": True}})
    return MessageResponse(message="Toutes les notifications marquées comme lues")


async def unread_count(user: User) -> dict:
    count = await Notification.find(
        Notification.user_id == str(user.id),
        Notification.is_read == False,
    ).count()
    return {"count": count}
