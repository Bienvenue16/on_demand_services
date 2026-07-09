from starlette.requests import Request
from starlette.responses import Response
from starlette_admin.auth import AuthProvider, AdminUser
from starlette_admin.exceptions import LoginFailed
from starlette_admin.contrib.beanie import ModelView, Admin
from starlette_admin import (
    StringField, EmailField, BooleanField, DateTimeField,
    EnumField, IntegerField, FloatField, TextAreaField, JSONField,
)


# ---------------------------------------------------------------------------
# Auth provider
# ---------------------------------------------------------------------------

class AdminAuthProvider(AuthProvider):
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
# Vues modèles
# ---------------------------------------------------------------------------

def build_admin_views(admin: Admin) -> None:
    from app.models.user import User, UserRole
    from app.models.provider_profile import ProviderProfile, ProviderValidationStatus
    from app.models.category import Category
    from app.models.report import Report, ReportType, ReportStatus, ReportSeverity
    from app.models.audit_log import AuditLog

    # ------------------------------------------------------------------
    # Utilisateurs (liste unique, role modifiable)
    # ------------------------------------------------------------------
    class UserView(ModelView):
        fields = [
            StringField("id", read_only=True),
            EmailField("email"),
            StringField("full_name", label="Nom complet"),
            StringField("phone", label="Téléphone", required=False),
            EnumField("role", enum=UserRole),
            BooleanField("is_verified", label="Vérifié"),
            BooleanField("is_active", label="Actif"),
            BooleanField("is_banned", label="Banni"),
            StringField("banned_reason", label="Raison du ban", required=False),
            DateTimeField("banned_at", label="Banni le", read_only=True),
            DateTimeField("last_active", label="Dernière activité", read_only=True),
            DateTimeField("created_at", label="Créé le", read_only=True),
        ]
        column_list = ["email", "full_name", "role", "is_active", "is_banned", "created_at"]
        column_sortable_list = ["email", "full_name", "role", "created_at"]
        column_searchable_list = ["email", "full_name"]
        exclude_fields_from_create = ["id", "created_at", "last_active", "banned_at"]
        exclude_fields_from_edit   = ["id", "created_at", "last_active", "banned_at"]

    # ------------------------------------------------------------------
    # Profils prestataires
    # ------------------------------------------------------------------
    class ProviderProfileView(ModelView):
        fields = [
            StringField("id", read_only=True),
            StringField("user_id", label="ID utilisateur", read_only=True),
            TextAreaField("bio", label="Biographie", required=False),
            EnumField("validation_status", enum=ProviderValidationStatus, label="Statut validation"),
            TextAreaField("validation_notes", label="Notes validation", required=False),
            BooleanField("is_verified_provider", label="Prestataire vérifié"),
            FloatField("avg_rating", label="Note moyenne", read_only=True),
            IntegerField("total_reviews", label="Nb avis", read_only=True),
            StringField("id_card_url", label="URL pièce d'identité", required=False),
            DateTimeField("updated_at", label="Mis à jour le", read_only=True),
        ]
        column_list = ["user_id", "validation_status", "is_verified_provider", "avg_rating", "updated_at"]
        column_sortable_list = ["validation_status", "is_verified_provider", "avg_rating", "updated_at"]
        exclude_fields_from_create = ["id", "avg_rating", "total_reviews", "updated_at"]
        exclude_fields_from_edit   = ["id", "avg_rating", "total_reviews"]

    # ------------------------------------------------------------------
    # Catégories
    # ------------------------------------------------------------------
    class CategoryView(ModelView):
        fields = [
            StringField("id", read_only=True),
            StringField("name", label="Nom"),
            StringField("slug", label="Slug"),
            StringField("icon", label="Icône", required=False),
            BooleanField("is_active", label="Active"),
        ]
        column_list = ["name", "slug", "is_active"]
        column_sortable_list = ["name", "is_active"]
        column_searchable_list = ["name", "slug"]
        exclude_fields_from_create = ["id"]
        exclude_fields_from_edit   = ["id"]

    # ------------------------------------------------------------------
    # Signalements
    # ------------------------------------------------------------------
    class ReportView(ModelView):
        fields = [
            StringField("id", read_only=True),
            StringField("reporter_id", label="Signalé par", read_only=True),
            EnumField("target_type", enum=ReportType, label="Type cible"),
            StringField("target_id", label="ID cible"),
            TextAreaField("reason", label="Raison"),
            TextAreaField("description", label="Description", required=False),
            EnumField("severity", enum=ReportSeverity, label="Gravité"),
            EnumField("status", enum=ReportStatus, label="Statut"),
            StringField("resolved_by", label="Résolu par", required=False, read_only=True),
            DateTimeField("created_at", label="Créé le", read_only=True),
            DateTimeField("updated_at", label="Mis à jour le", read_only=True),
        ]
        column_list = ["reporter_id", "target_type", "target_id", "severity", "status", "created_at"]
        column_sortable_list = ["severity", "status", "created_at"]
        exclude_fields_from_edit = ["id", "reporter_id", "resolved_by", "created_at", "updated_at"]

        def can_create(self, request: Request) -> bool:
            return False

    # ------------------------------------------------------------------
    # Audit logs (lecture seule)
    # ------------------------------------------------------------------
    class AuditLogView(ModelView):
        fields = [
            StringField("id", read_only=True),
            StringField("admin_id", label="ID admin", read_only=True),
            EmailField("admin_email", label="Email admin", read_only=True),
            StringField("action", label="Action", read_only=True),
            StringField("target_type", label="Type cible", read_only=True),
            StringField("target_id", label="ID cible", read_only=True),
            JSONField("detail", label="Détails", read_only=True),
            StringField("ip_address", label="IP", read_only=True),
            DateTimeField("created_at", label="Date", read_only=True),
        ]
        column_list = ["admin_email", "action", "target_type", "target_id", "ip_address", "created_at"]
        column_sortable_list = ["action", "created_at"]
        column_searchable_list = ["admin_email", "action"]

        def can_create(self, request: Request) -> bool:
            return False

        def can_edit(self, request: Request) -> bool:
            return False

        def can_delete(self, request: Request) -> bool:
            return False

    # ------------------------------------------------------------------
    # Montage des vues avec menu organisé
    # ------------------------------------------------------------------
    from app.models.service_request import ServiceRequest, RequestStatus, Urgency
    from app.models.proposal import Proposal, ProposalStatus
    from app.models.review import Review
    from app.models.message import Message
    from app.models.notification import Notification
    from app.models.blacklisted_token import BlacklistedToken

    # ------------------------------------------------------------------
    # Demandes de service
    # ------------------------------------------------------------------
    class ServiceRequestView(ModelView):
        fields = [
            StringField("id", read_only=True),
            StringField("client_id", label="Client ID", read_only=True),
            StringField("category_id", label="Catégorie ID"),
            StringField("title", label="Titre"),
            TextAreaField("description", label="Description"),
            EnumField("urgency", enum=Urgency, label="Urgence"),
            EnumField("status", enum=RequestStatus, label="Statut"),
            DateTimeField("created_at", label="Créé le", read_only=True),
            DateTimeField("updated_at", label="Mis à jour le", read_only=True),
        ]
        column_list = ["title", "client_id", "category_id", "urgency", "status", "created_at"]
        column_sortable_list = ["urgency", "status", "created_at"]
        column_searchable_list = ["title"]
        exclude_fields_from_create = ["id", "created_at", "updated_at"]
        exclude_fields_from_edit   = ["id", "client_id", "created_at", "updated_at"]

    # ------------------------------------------------------------------
    # Propositions
    # ------------------------------------------------------------------
    class ProposalView(ModelView):
        fields = [
            StringField("id", read_only=True),
            StringField("request_id", label="Demande ID", read_only=True),
            StringField("provider_id", label="Prestataire ID", read_only=True),
            TextAreaField("message", label="Message"),
            FloatField("price_estimate", label="Prix estimé", required=False),
            EnumField("status", enum=ProposalStatus, label="Statut"),
            DateTimeField("created_at", label="Créé le", read_only=True),
        ]
        column_list = ["request_id", "provider_id", "price_estimate", "status", "created_at"]
        column_sortable_list = ["status", "price_estimate", "created_at"]
        exclude_fields_from_create = ["id", "created_at"]
        exclude_fields_from_edit   = ["id", "request_id", "provider_id", "created_at"]

    # ------------------------------------------------------------------
    # Avis
    # ------------------------------------------------------------------
    class ReviewView(ModelView):
        fields = [
            StringField("id", read_only=True),
            StringField("request_id", label="Demande ID", read_only=True),
            StringField("reviewer_id", label="Auteur ID", read_only=True),
            StringField("provider_id", label="Prestataire ID", read_only=True),
            IntegerField("rating", label="Note (1-5)"),
            TextAreaField("comment", label="Commentaire", required=False),
            DateTimeField("created_at", label="Créé le", read_only=True),
        ]
        column_list = ["reviewer_id", "provider_id", "rating", "comment", "created_at"]
        column_sortable_list = ["rating", "created_at"]
        exclude_fields_from_create = ["id", "created_at"]
        exclude_fields_from_edit   = ["id", "request_id", "reviewer_id", "provider_id", "created_at"]

    # ------------------------------------------------------------------
    # Messages
    # ------------------------------------------------------------------
    class MessageView(ModelView):
        fields = [
            StringField("id", read_only=True),
            StringField("room_id", label="Room ID", read_only=True),
            StringField("sender_id", label="Expéditeur ID", read_only=True),
            TextAreaField("content", label="Contenu"),
            StringField("media_url", label="Média URL", required=False),
            BooleanField("is_read", label="Lu"),
            DateTimeField("created_at", label="Créé le", read_only=True),
        ]
        column_list = ["room_id", "sender_id", "content", "is_read", "created_at"]
        column_sortable_list = ["created_at", "is_read"]
        column_searchable_list = ["content"]
        exclude_fields_from_create = ["id", "created_at"]
        exclude_fields_from_edit   = ["id", "room_id", "sender_id", "created_at"]

        def can_create(self, request: Request) -> bool:
            return False

    # ------------------------------------------------------------------
    # Notifications
    # ------------------------------------------------------------------
    class NotificationView(ModelView):
        fields = [
            StringField("id", read_only=True),
            StringField("user_id", label="Utilisateur ID", read_only=True),
            StringField("type", label="Type"),
            StringField("title", label="Titre"),
            TextAreaField("body", label="Corps"),
            BooleanField("is_read", label="Lue"),
            StringField("ref_id", label="Réf. ID", required=False),
            DateTimeField("created_at", label="Créé le", read_only=True),
        ]
        column_list = ["user_id", "type", "title", "is_read", "created_at"]
        column_sortable_list = ["type", "is_read", "created_at"]
        exclude_fields_from_create = ["id", "created_at"]
        exclude_fields_from_edit   = ["id", "user_id", "created_at"]

    # ------------------------------------------------------------------
    # Tokens révoqués (lecture seule)
    # ------------------------------------------------------------------
    class BlacklistedTokenView(ModelView):
        fields = [
            StringField("id", read_only=True),
            StringField("user_id", label="Utilisateur ID", read_only=True),
            DateTimeField("blacklisted_at", label="Révoqué le", read_only=True),
            DateTimeField("expires_at", label="Expire le", read_only=True),
        ]
        column_list = ["user_id", "blacklisted_at", "expires_at"]
        column_sortable_list = ["blacklisted_at", "expires_at"]

        def can_create(self, request: Request) -> bool:
            return False

        def can_edit(self, request: Request) -> bool:
            return False

    admin.add_view(UserView(User, icon="fa fa-users", label="Utilisateurs"))
    admin.add_view(ProviderProfileView(ProviderProfile, icon="fa fa-id-card", label="Profils prestataires"))
    admin.add_view(ServiceRequestView(ServiceRequest, icon="fa fa-briefcase", label="Demandes de service"))
    admin.add_view(ProposalView(Proposal, icon="fa fa-paper-plane", label="Propositions"))
    admin.add_view(ReviewView(Review, icon="fa fa-star", label="Avis"))
    admin.add_view(MessageView(Message, icon="fa fa-comments", label="Messages"))
    admin.add_view(NotificationView(Notification, icon="fa fa-bell", label="Notifications"))
    admin.add_view(CategoryView(Category, icon="fa fa-tags", label="Catégories"))
    admin.add_view(ReportView(Report, icon="fa fa-flag", label="Signalements"))
    admin.add_view(AuditLogView(AuditLog, icon="fa fa-history", label="Audit Logs"))
    admin.add_view(BlacklistedTokenView(BlacklistedToken, icon="fa fa-ban", label="Tokens révoqués"))

