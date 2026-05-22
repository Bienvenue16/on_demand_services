import csv
import io
from datetime import datetime, timezone
from typing import Optional, List
from fastapi import HTTPException, status

from app.models.user import User, UserRole
from app.models.provider_profile import ProviderProfile, ProviderValidationStatus, ValidationHistoryEntry
from app.models.report import Report, ReportStatus, ModerationAction
from app.models.audit_log import AuditLog
from app.models.notification import Notification
from app.models.review import Review
from app.models.service_request import ServiceRequest
from app.models.blacklisted_token import BlacklistedToken
from app.core.security import blacklist_token


# ---------------------------------------------------------------------------
# Audit trail
# ---------------------------------------------------------------------------

async def log_action(admin: User, action: str, target_type: str = None,
                     target_id: str = None, detail: dict = None, ip: str = None) -> None:
    await AuditLog(
        admin_id=str(admin.id),
        admin_email=admin.email,
        action=action,
        target_type=target_type,
        target_id=target_id,
        detail=detail,
        ip_address=ip,
    ).insert()


# ---------------------------------------------------------------------------
# Dashboard / Statistiques
# ---------------------------------------------------------------------------

async def get_stats() -> dict:
    total_users = await User.count()
    total_providers = await User.find(User.role == UserRole.provider).count()
    total_clients = await User.find(User.role == UserRole.client).count()
    banned_users = await User.find(User.is_banned == True).count()
    total_requests = await ServiceRequest.count()
    pending_validations = await ProviderProfile.find(
        ProviderProfile.validation_status == ProviderValidationStatus.pending
    ).count()
    pending_reports = await Report.find(Report.status == ReportStatus.pending).count()

    return {
        "users": {
            "total": total_users,
            "providers": total_providers,
            "clients": total_clients,
            "banned": banned_users,
        },
        "service_requests": {"total": total_requests},
        "pending_validations": pending_validations,
        "pending_reports": pending_reports,
    }


# ---------------------------------------------------------------------------
# Gestion des utilisateurs
# ---------------------------------------------------------------------------

async def list_users(role: Optional[str] = None, is_banned: Optional[bool] = None,
                     search: Optional[str] = None, page: int = 1, limit: int = 20) -> dict:
    query = User.find()
    if role:
        query = User.find(User.role == role)
    if is_banned is not None:
        query = query.find(User.is_banned == is_banned)
    total = await query.count()
    skip = (page - 1) * limit
    users = await query.skip(skip).limit(limit).to_list()
    return {"total": total, "page": page, "limit": limit, "data": users}


async def get_user_detail(user_id: str) -> dict:
    user = await User.get(user_id)
    if not user:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Utilisateur introuvable")
    profile = await ProviderProfile.find_one(ProviderProfile.user_id == user_id)
    requests = await ServiceRequest.find(ServiceRequest.client_id == user_id).to_list()
    return {"user": user, "profile": profile, "requests_count": len(requests)}


async def ban_user(admin: User, user_id: str, reason: str, token_to_blacklist: Optional[str] = None) -> User:
    user = await User.get(user_id)
    if not user:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Utilisateur introuvable")
    if user.role == UserRole.admin:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="Impossible de bannir un admin")
    user.is_banned = True
    user.banned_reason = reason
    user.banned_at = datetime.now(timezone.utc)
    user.banned_by = str(admin.id)
    user.refresh_token = None
    await user.save()
    if token_to_blacklist:
        await blacklist_token(token_to_blacklist, user_id)
    await log_action(admin, "ban_user", "user", user_id, {"reason": reason})
    await Notification(
        user_id=user_id, type="account",
        title="Compte suspendu",
        body=f"Votre compte a été suspendu. Motif : {reason}",
    ).insert()
    return user


async def unban_user(admin: User, user_id: str) -> User:
    user = await User.get(user_id)
    if not user:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Utilisateur introuvable")
    user.is_banned = False
    user.banned_reason = None
    user.banned_at = None
    user.banned_by = None
    await user.save()
    await log_action(admin, "unban_user", "user", user_id)
    await Notification(
        user_id=user_id, type="account",
        title="Compte réactivé",
        body="Votre compte a été réactivé. Vous pouvez à nouveau utiliser la plateforme.",
    ).insert()
    return user


async def change_user_role(admin: User, user_id: str, new_role: str) -> User:
    user = await User.get(user_id)
    if not user:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Utilisateur introuvable")
    old_role = user.role
    user.role = new_role
    await user.save()
    await log_action(admin, "change_role", "user", user_id, {"old": old_role, "new": new_role})
    return user


async def export_users_csv(role: Optional[str] = None) -> str:
    query = User.find(User.role == role) if role else User.find()
    users = await query.to_list()
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(["id", "email", "full_name", "phone", "role", "is_verified", "is_active", "is_banned", "created_at"])
    for u in users:
        writer.writerow([str(u.id), u.email, u.full_name, u.phone or "", u.role,
                         u.is_verified, u.is_active, u.is_banned, u.created_at.isoformat()])
    return output.getvalue()


# ---------------------------------------------------------------------------
# Validation des prestataires
# ---------------------------------------------------------------------------

async def list_providers_by_status(validation_status: str, page: int = 1, limit: int = 20) -> dict:
    query = ProviderProfile.find(ProviderProfile.validation_status == validation_status)
    total = await query.count()
    data = await query.skip((page - 1) * limit).limit(limit).to_list()
    return {"total": total, "page": page, "limit": limit, "data": data}


async def update_provider_validation(admin: User, profile_id: str,
                                     new_status: str, note: Optional[str] = None) -> ProviderProfile:
    profile = await ProviderProfile.get(profile_id)
    if not profile:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Profil introuvable")

    profile.validation_status = new_status
    profile.validation_notes = note
    profile.validation_history.append(
        ValidationHistoryEntry(status=new_status, note=note, admin_id=str(admin.id))
    )

    if new_status == ProviderValidationStatus.approved:
        profile.is_verified_provider = True

    await profile.save()
    await log_action(admin, "validate_provider", "provider_profile", profile_id,
                     {"status": new_status, "note": note})
    msg_map = {
        "approved": ("Profil validé", "Félicitations ! Votre profil prestataire a été validé."),
        "rejected": ("Profil refusé", f"Votre profil prestataire a été refusé. Motif : {note or 'non précisé'}"),
        "waiting_docs": ("Documents requis", f"Veuillez fournir des documents complémentaires : {note or ''}"),
    }
    if new_status in msg_map:
        title, body = msg_map[new_status]
        await Notification(user_id=profile.user_id, type="validation", title=title, body=body).insert()

    return profile


# ---------------------------------------------------------------------------
# Modération des signalements
# ---------------------------------------------------------------------------

async def list_reports(report_status: Optional[str] = None, page: int = 1, limit: int = 20) -> dict:
    query = Report.find(Report.status == report_status) if report_status else Report.find()
    total = await query.count()
    data = await query.skip((page - 1) * limit).limit(limit).to_list()
    return {"total": total, "page": page, "limit": limit, "data": data}


async def resolve_report(admin: User, report_id: str, action: str, note: Optional[str] = None) -> Report:
    report = await Report.get(report_id)
    if not report:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Signalement introuvable")
    report.status = ReportStatus.resolved
    report.resolved_by = str(admin.id)
    report.moderation_history.append(
        ModerationAction(admin_id=str(admin.id), action=action, note=note)
    )
    report.updated_at = datetime.now(timezone.utc)
    await report.save()
    await log_action(admin, "resolve_report", "report", report_id, {"action": action, "note": note})
    return report


async def dismiss_report(admin: User, report_id: str, note: Optional[str] = None) -> Report:
    report = await Report.get(report_id)
    if not report:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Signalement introuvable")
    report.status = ReportStatus.dismissed
    report.resolved_by = str(admin.id)
    report.moderation_history.append(
        ModerationAction(admin_id=str(admin.id), action="dismissed", note=note)
    )
    report.updated_at = datetime.now(timezone.utc)
    await report.save()
    await log_action(admin, "dismiss_report", "report", report_id)
    return report


# ---------------------------------------------------------------------------
# Suppression de contenu
# ---------------------------------------------------------------------------

async def delete_review(admin: User, review_id: str, reason: str) -> None:
    review = await Review.get(review_id)
    if not review:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Avis introuvable")
    await review.delete()
    await log_action(admin, "delete_review", "review", review_id, {"reason": reason})


async def close_service_request(admin: User, request_id: str, reason: str) -> ServiceRequest:
    from app.models.service_request import RequestStatus
    req = await ServiceRequest.get(request_id)
    if not req:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Demande introuvable")
    req.status = RequestStatus.cancelled
    await req.save()
    await log_action(admin, "close_request", "service_request", request_id, {"reason": reason})
    return req


# ---------------------------------------------------------------------------
# Notifications broadcast
# ---------------------------------------------------------------------------

async def broadcast_notification(admin: User, title: str, body: str,
                                  target: str = "all", user_ids: Optional[List[str]] = None) -> dict:
    """Envoie une notification in-app à tous les users, un segment ou une liste."""
    if target == "all":
        users = await User.find(User.is_banned == False).to_list()
    elif target == "clients":
        users = await User.find(User.role == UserRole.client, User.is_banned == False).to_list()
    elif target == "providers":
        users = await User.find(User.role == UserRole.provider, User.is_banned == False).to_list()
    elif target == "specific" and user_ids:
        users = []
        for uid in user_ids:
            u = await User.get(uid)
            if u:
                users.append(u)
    else:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="Cible invalide")

    notifications = [
        Notification(user_id=str(u.id), type="broadcast", title=title, body=body)
        for u in users
    ]
    if notifications:
        await Notification.insert_many(notifications)

    await log_action(admin, "broadcast_notification", detail={
        "target": target, "count": len(notifications), "title": title
    })
    return {"sent_to": len(notifications)}


# ---------------------------------------------------------------------------
# Audit logs & Tokens blacklistés
# ---------------------------------------------------------------------------

async def get_audit_logs(page: int = 1, limit: int = 50) -> dict:
    total = await AuditLog.count()
    data = await AuditLog.find().sort(-AuditLog.created_at).skip((page - 1) * limit).limit(limit).to_list()
    return {"total": total, "page": page, "limit": limit, "data": data}


async def cleanup_expired_tokens() -> int:
    """Supprime les tokens blacklistés expirés (appelé manuellement ou via tâche planifiée)."""
    now = datetime.now(timezone.utc)
    result = await BlacklistedToken.find(BlacklistedToken.expires_at < now).delete()
    return result
