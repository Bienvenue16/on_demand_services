from typing import Optional
from urllib.parse import quote

from fastapi import APIRouter, Form, Request
from fastapi.responses import RedirectResponse
from fastapi.templating import Jinja2Templates

from app.models.user import User, UserRole
from app.services import admin_service

router = APIRouter()
templates = Jinja2Templates(directory="app/templates")


async def _current_admin(request: Request) -> Optional[User]:
    """Reutilise la session ouverte via /admin-panel/login (starlette_admin)."""
    admin_id = request.session.get("admin_id")
    if not admin_id:
        return None
    user = await User.get(admin_id)
    if not user or user.role != UserRole.admin:
        return None
    return user


@router.get("/dashboard")
async def dashboard(request: Request):
    admin = await _current_admin(request)
    if admin is None:
        return RedirectResponse(url="/admin-panel/login")

    stats = await admin_service.get_stats()
    return templates.TemplateResponse(
        request,
        "admin_dashboard.html",
        {
            "admin": admin,
            "stats": stats,
            "message": request.query_params.get("message"),
        },
    )


@router.post("/dashboard/broadcast")
async def broadcast(
    request: Request,
    title: str = Form(...),
    body: str = Form(...),
    target: str = Form("all"),
):
    admin = await _current_admin(request)
    if admin is None:
        return RedirectResponse(url="/admin-panel/login", status_code=303)

    result = await admin_service.broadcast_notification(admin, title, body, target)
    message = f"Notification envoyée à {result['sent_to']} utilisateur(s)."
    return RedirectResponse(
        url=f"/admin/dashboard?message={quote(message)}", status_code=303
    )
