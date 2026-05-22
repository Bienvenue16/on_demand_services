from fastapi import APIRouter, Depends, Query, HTTPException, status
from fastapi.responses import StreamingResponse
from typing import Optional, List
import io

from app.core.security import get_admin_user
from app.services import admin_service
from app.models.category import Category
from app.schemas.category import CategoryCreate, CategoryOut, CategoryUpdate
from app.schemas.common import MessageResponse

router = APIRouter()


# ---------------------------------------------------------------------------
# Dashboard
# ---------------------------------------------------------------------------

@router.get("/stats")
async def get_stats(admin=Depends(get_admin_user)):
    return await admin_service.get_stats()


# ---------------------------------------------------------------------------
# Gestion des utilisateurs
# ---------------------------------------------------------------------------

@router.get("/users")
async def list_users(
    role: Optional[str] = None,
    is_banned: Optional[bool] = None,
    search: Optional[str] = None,
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    admin=Depends(get_admin_user),
):
    return await admin_service.list_users(role, is_banned, search, page, limit)


@router.get("/users/{user_id}")
async def get_user_detail(user_id: str, admin=Depends(get_admin_user)):
    return await admin_service.get_user_detail(user_id)


@router.post("/users/{user_id}/ban")
async def ban_user(
    user_id: str,
    reason: str = Query(..., min_length=5),
    admin=Depends(get_admin_user),
):
    return await admin_service.ban_user(admin, user_id, reason)


@router.post("/users/{user_id}/unban")
async def unban_user(user_id: str, admin=Depends(get_admin_user)):
    return await admin_service.unban_user(admin, user_id)


@router.patch("/users/{user_id}/role")
async def change_role(
    user_id: str,
    new_role: str = Query(..., pattern="^(client|provider|admin)$"),
    admin=Depends(get_admin_user),
):
    return await admin_service.change_user_role(admin, user_id, new_role)


@router.get("/users/export/csv")
async def export_users(role: Optional[str] = None, admin=Depends(get_admin_user)):
    csv_content = await admin_service.export_users_csv(role)
    return StreamingResponse(
        io.StringIO(csv_content),
        media_type="text/csv",
        headers={"Content-Disposition": "attachment; filename=users.csv"},
    )


# ---------------------------------------------------------------------------
# Validation des prestataires
# ---------------------------------------------------------------------------

@router.get("/providers/validation")
async def list_pending_providers(
    validation_status: str = Query("pending"),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    admin=Depends(get_admin_user),
):
    return await admin_service.list_providers_by_status(validation_status, page, limit)


@router.patch("/providers/{profile_id}/validation")
async def update_provider_validation(
    profile_id: str,
    new_status: str = Query(..., pattern="^(reviewing|waiting_docs|approved|rejected)$"),
    note: Optional[str] = None,
    admin=Depends(get_admin_user),
):
    return await admin_service.update_provider_validation(admin, profile_id, new_status, note)


# ---------------------------------------------------------------------------
# Signalements / Modération
# ---------------------------------------------------------------------------

@router.get("/reports")
async def list_reports(
    report_status: Optional[str] = None,
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    admin=Depends(get_admin_user),
):
    return await admin_service.list_reports(report_status, page, limit)


@router.patch("/reports/{report_id}/resolve")
async def resolve_report(
    report_id: str,
    action: str = Query(...),
    note: Optional[str] = None,
    admin=Depends(get_admin_user),
):
    return await admin_service.resolve_report(admin, report_id, action, note)


@router.patch("/reports/{report_id}/dismiss")
async def dismiss_report(
    report_id: str,
    note: Optional[str] = None,
    admin=Depends(get_admin_user),
):
    return await admin_service.dismiss_report(admin, report_id, note)


# ---------------------------------------------------------------------------
# Gestion du contenu
# ---------------------------------------------------------------------------

@router.delete("/reviews/{review_id}", response_model=MessageResponse)
async def delete_review(
    review_id: str,
    reason: str = Query(..., min_length=5),
    admin=Depends(get_admin_user),
):
    await admin_service.delete_review(admin, review_id, reason)
    return MessageResponse(message="Avis supprimé")


@router.patch("/requests/{request_id}/close")
async def close_request(
    request_id: str,
    reason: str = Query(..., min_length=5),
    admin=Depends(get_admin_user),
):
    return await admin_service.close_service_request(admin, request_id, reason)


@router.post("/categories", status_code=201, response_model=CategoryOut)
async def create_category(body: CategoryCreate, admin=Depends(get_admin_user)):
    cat = Category(**body.model_dump())
    await cat.insert()
    return cat


@router.patch("/categories/{category_id}", response_model=CategoryOut)
async def update_category(category_id: str, body: CategoryUpdate, admin=Depends(get_admin_user)):
    cat = await Category.get(category_id)
    if not cat:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Catégorie introuvable")
    for k, v in body.model_dump(exclude_none=True).items():
        setattr(cat, k, v)
    await cat.save()
    return cat


@router.delete("/categories/{category_id}", response_model=MessageResponse)
async def delete_category(category_id: str, admin=Depends(get_admin_user)):
    cat = await Category.get(category_id)
    if not cat:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Catégorie introuvable")
    await cat.delete()
    return MessageResponse(message="Catégorie supprimée")


# ---------------------------------------------------------------------------
# Notifications broadcast
# ---------------------------------------------------------------------------

@router.post("/notifications/broadcast")
async def broadcast(
    title: str = Query(...),
    body: str = Query(...),
    target: str = Query("all", pattern="^(all|clients|providers|specific)$"),
    user_ids: Optional[List[str]] = Query(None),
    admin=Depends(get_admin_user),
):
    return await admin_service.broadcast_notification(admin, title, body, target, user_ids)


# ---------------------------------------------------------------------------
# Audit logs & Sécurité
# ---------------------------------------------------------------------------

@router.get("/audit-logs")
async def get_audit_logs(
    page: int = Query(1, ge=1),
    limit: int = Query(50, ge=1, le=200),
    admin=Depends(get_admin_user),
):
    return await admin_service.get_audit_logs(page, limit)


@router.delete("/tokens/cleanup", response_model=MessageResponse)
async def cleanup_tokens(admin=Depends(get_admin_user)):
    deleted = await admin_service.cleanup_expired_tokens()
    return MessageResponse(message=f"{deleted} token(s) expirés supprimés")

