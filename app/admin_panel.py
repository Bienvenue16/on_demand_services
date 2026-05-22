from starlette.requests import Request
from starlette.responses import Response
from starlette_admin.auth import AuthProvider, AdminUser, login_not_required
from starlette_admin.exceptions import LoginFailed
from starlette_admin.contrib.beanie import ModelView, Admin


# ---------------------------------------------------------------------------
# Auth provider — protège le panel avec email/password admin
# ---------------------------------------------------------------------------

class AdminAuthProvider(AuthProvider):
    """Vérifie les credentials admin en MongoDB."""

    async def login(self, username: str, password: str,
                    remember_me: bool, request: Request, response: Response):
        from app.models.user import User, UserRole
        from app.core.security import verify_password
        user = await User.find_one(User.email == username)
        if not user or user.role != UserRole.admin:
            raise LoginFailed("Email ou mot de passe invalide")
        if not verify_password(password, user.hashed_password):
            raise LoginFailed("Email ou mot de passe invalide")
        request.session["admin_id"] = str(user.id)
        request.session["admin_email"] = user.email
        return response

    async def is_authenticated(self, request: Request) -> bool:
        return "admin_id" in request.session

    def get_admin_user(self, request: Request) -> AdminUser:
        return AdminUser(username=request.session.get("admin_email", "Admin"))

    async def logout(self, request: Request, response: Response) -> Response:
        request.session.clear()
        return response


# ---------------------------------------------------------------------------
# Vues modèles pour le panel
# ---------------------------------------------------------------------------

def build_admin_views(admin: Admin) -> None:
    from app.models.user import User
    from app.models.provider_profile import ProviderProfile
    from app.models.category import Category
    from app.models.report import Report
    from app.models.audit_log import AuditLog

    class UserView(ModelView):
        column_list = ["id", "email", "full_name", "role", "is_active", "is_banned", "created_at"]
        column_searchable_list = ["email", "full_name"]
        column_sortable_list = ["created_at", "role", "is_banned"]

    class ProviderProfileView(ModelView):
        column_list = ["id", "user_id", "validation_status", "is_verified_provider"]

    class CategoryView(ModelView):
        column_list = ["id", "name", "is_active"]

    class ReportView(ModelView):
        column_list = ["id", "reporter_id", "target_id", "target_type", "status", "severity", "created_at"]

    class AuditLogView(ModelView):
        column_list = ["id", "admin_email", "action", "target_type", "target_id", "created_at"]
        can_create = False
        can_edit = False
        can_delete = False

    admin.add_view(UserView(User, icon="fa fa-users", label="Utilisateurs"))
    admin.add_view(ProviderProfileView(ProviderProfile, icon="fa fa-id-card", label="Profils prestataires"))
    admin.add_view(CategoryView(Category, icon="fa fa-tags", label="Catégories"))
    admin.add_view(ReportView(Report, icon="fa fa-flag", label="Signalements"))
    admin.add_view(AuditLogView(AuditLog, icon="fa fa-history", label="Audit Logs"))
