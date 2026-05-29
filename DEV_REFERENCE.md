# DEV REFERENCE — API FastAPI · Services à la Demande

> Référence technique complète pour le développement de l'API.  
> Stack : **FastAPI · MongoDB Atlas · Beanie · Pydantic v2 · JWT · WebSocket · starlette-admin**  
> Dernière mise à jour : Mai 2026

---

## Stack & Versions

```
fastapi>=0.111.0
uvicorn[standard]>=0.29.0
motor>=3.4.0
beanie==1.26.0               # ⚠ pinné — beanie 2.x incompatible avec Motor
pydantic[email]>=2.7.0
pydantic-settings>=2.2.0
python-jose[cryptography]>=3.3.0
bcrypt>=4.0.0,<5.0.0         # ⚠ passlib supprimé — incompatible bcrypt 4/5.x
aiosmtplib>=3.0.0
python-multipart>=0.0.9
aiofiles>=23.2.1
python-dotenv>=1.0.1
itsdangerous>=2.0.0          # requis par SessionMiddleware (starlette-admin)
tzdata>=2024.1               # requis par zoneinfo sur Windows
starlette-admin>=0.14.0      # panel admin UI sur /admin-panel
# dev
pytest>=8.2.0
pytest-asyncio>=0.23.0
httpx>=0.27.0
```

> **Dépendances critiques :**
> - Ne pas installer le package `bson` standalone — conflit avec pymongo
> - Ne pas utiliser `passlib` — utiliser `bcrypt` directement

---

## Structure des fichiers

```
api_fast/
├── .env
├── .env.example
├── requirements.txt
├── create_admin.py             # script one-shot création admin (si pas de SUPER_ADMIN_*)
├── openapi.json                # export OpenAPI (généré via GET /openapi.json)
│
├── app/
│   ├── main.py                 # lifespan, CORS, middlewares, routeurs, panel admin
│   ├── admin_panel.py          # starlette-admin : AuthProvider + vues modèles
│   │
│   ├── core/
│   │   ├── config.py           # Settings (pydantic-settings) + vars SUPER_ADMIN_*
│   │   ├── database.py         # init Beanie + Motor + création super admin au démarrage
│   │   ├── security.py         # JWT, bcrypt, blacklist tokens, get_current_user
│   │   ├── email.py            # SMTP async (aiosmtplib)
│   │   └── exceptions.py       # handlers HTTP globaux
│   │
│   ├── models/
│   │   ├── __init__.py         # exporte tous les Documents → init Beanie
│   │   ├── user.py             # + champs ban, last_active, prev_refresh_token
│   │   ├── provider_profile.py # + workflow validation (5 statuts, historique)
│   │   ├── service_request.py
│   │   ├── proposal.py
│   │   ├── message.py
│   │   ├── review.py
│   │   ├── notification.py
│   │   ├── category.py
│   │   ├── report.py           # NEW — signalements/modération
│   │   ├── audit_log.py        # NEW — journal actions admin
│   │   └── blacklisted_token.py # NEW — tokens JWT révoqués
│   │
│   ├── schemas/
│   │   ├── auth.py
│   │   ├── user.py
│   │   ├── service_request.py
│   │   ├── proposal.py
│   │   ├── message.py
│   │   ├── review.py
│   │   ├── notification.py
│   │   ├── category.py
│   │   └── common.py           # PaginatedResponse, MessageResponse, PyObjectId
│   │
│   ├── routers/
│   │   ├── auth.py
│   │   ├── users.py
│   │   ├── requests.py
│   │   ├── proposals.py
│   │   ├── messages.py
│   │   ├── websocket.py
│   │   ├── reviews.py
│   │   ├── notifications.py
│   │   ├── categories.py
│   │   ├── uploads.py
│   │   └── admin.py            # 20+ endpoints admin complets
│   │
│   ├── services/
│   │   ├── auth_service.py     # register (auto-verify DEBUG), login, refresh (grace period)
│   │   ├── user_service.py
│   │   ├── request_service.py
│   │   ├── proposal_service.py
│   │   ├── message_service.py
│   │   ├── review_service.py
│   │   ├── notification_service.py
│   │   ├── file_service.py
│   │   ├── geo_service.py
│   │   └── admin_service.py    # NEW — toute la logique métier admin
│   │
│   ├── websocket/
│   │   ├── manager.py
│   │   └── handlers.py
│   │
│   └── utils/
│       ├── pagination.py
│       ├── validators.py
│       └── helpers.py
│
├── uploads/
│   ├── avatars/
│   ├── portfolio/
│   ├── requests/
│   ├── messages/
│   └── certificates/
│
└── tests/
    ├── conftest.py
    ├── test_auth.py
    ├── test_requests.py
    └── test_proposals.py
```

---

## Variables d'environnement (.env)

```env
APP_NAME="Services à la Demande"
APP_ENV=development
DEBUG=true                          # true → auto-verify email, CORS *, skip is_verified check

SECRET_KEY="change-me-to-a-long-random-string-minimum-32-chars"
CORS_ORIGINS="http://localhost:3000,http://localhost:8081"

MONGODB_URL=mongodb+srv://user:password@cluster0.xxxxx.mongodb.net/?appName=Cluster0
DB_NAME=services_app

JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=15
REFRESH_TOKEN_EXPIRE_DAYS=7

UPLOAD_DIR=./uploads
MAX_FILE_SIZE_MB=10
STATIC_URL="http://localhost:8000/static"

SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER="ton.email@gmail.com"
SMTP_PASSWORD="ton-app-password-gmail"
EMAIL_FROM="Services App <ton.email@gmail.com>"

# Super admin créé automatiquement au démarrage si absent en base
SUPER_ADMIN_EMAIL="admin@services.com"
SUPER_ADMIN_PASSWORD="ChangeMe123!"
SUPER_ADMIN_NAME="Super Admin"

PUSH_NOTIFICATIONS_ENABLED=false
SMS_ENABLED=false
GOOGLE_OAUTH_ENABLED=false
GOOGLE_MAPS_ENABLED=false
OCR_ENABLED=false
CLOUD_STORAGE_ENABLED=false
REDIS_ENABLED=false
```

> **Mode DEBUG (`DEBUG=true`) :**
> - Inscription : compte auto-vérifié, pas d'email envoyé
> - Login : vérification email/is_active ignorée
> - CORS : `allow_origins=["*"]`, `allow_credentials=False`

---

## app/main.py — Point d'entrée

```python
from contextlib import asynccontextmanager
from bson import ObjectId
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.encoders import ENCODERS_BY_TYPE
from starlette.middleware.sessions import SessionMiddleware
from starlette_admin.contrib.beanie import Admin
from app.core.config import settings
from app.core.database import init_db
from app.core.exceptions import add_exception_handlers
from app.routers import auth, users, requests, proposals, messages, websocket, \
                        reviews, notifications, categories, uploads, admin
from app.admin_panel import AdminAuthProvider, build_admin_views

# Sérialise tous les ObjectId MongoDB en string automatiquement
ENCODERS_BY_TYPE[ObjectId] = str

@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()   # connexion MongoDB + init Beanie + création super admin
    yield

app = FastAPI(title=settings.APP_NAME, lifespan=lifespan)
add_exception_handlers(app)

app.add_middleware(SessionMiddleware, secret_key=settings.SECRET_KEY)

cors_origins = ["*"] if settings.DEBUG else settings.CORS_ORIGINS.split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=not settings.DEBUG,  # credentials incompatible avec ["*"]
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/static", StaticFiles(directory=settings.UPLOAD_DIR), name="static")

app.include_router(auth.router,          prefix="/auth",          tags=["Auth"])
app.include_router(users.router,         prefix="/users",         tags=["Users"])
app.include_router(requests.router,      prefix="/requests",      tags=["Requests"])
app.include_router(proposals.router,     prefix="/proposals",     tags=["Proposals"])
app.include_router(messages.router,      prefix="/messages",      tags=["Messages"])
app.include_router(websocket.router,     prefix="/ws",            tags=["WebSocket"])
app.include_router(reviews.router,       prefix="/reviews",       tags=["Reviews"])
app.include_router(notifications.router, prefix="/notifications", tags=["Notifications"])
app.include_router(categories.router,    prefix="/categories",    tags=["Categories"])
app.include_router(uploads.router,       prefix="/uploads",       tags=["Uploads"])
app.include_router(admin.router,         prefix="/admin",         tags=["Admin"])

# Panel admin UI — http://localhost:8000/admin-panel
admin_panel = Admin(title="Services App — Admin", auth_provider=AdminAuthProvider(), base_url="/admin-panel")
build_admin_views(admin_panel)
admin_panel.mount_to(app)
```

---

## app/core/config.py

```python
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    APP_NAME: str = "Services à la Demande"
    APP_ENV: str = "development"
    DEBUG: bool = True
    SECRET_KEY: str = "change-me"
    CORS_ORIGINS: str = "http://localhost:3000"

    MONGODB_URL: str = ""
    DB_NAME: str = "services_app"

    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    UPLOAD_DIR: str = "./uploads"
    MAX_FILE_SIZE_MB: int = 10
    STATIC_URL: str = "http://localhost:8000/static"

    SMTP_HOST: str = "smtp.gmail.com"
    SMTP_PORT: int = 587
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""
    EMAIL_FROM: str = "Services App <noreply@example.com>"

    SUPER_ADMIN_EMAIL: str = ""
    SUPER_ADMIN_PASSWORD: str = ""
    SUPER_ADMIN_NAME: str = "Super Admin"

    PUSH_NOTIFICATIONS_ENABLED: bool = False
    SMS_ENABLED: bool = False
    GOOGLE_OAUTH_ENABLED: bool = False
    GOOGLE_MAPS_ENABLED: bool = False
    OCR_ENABLED: bool = False
    CLOUD_STORAGE_ENABLED: bool = False
    REDIS_ENABLED: bool = False

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"

settings = Settings()
```

---

## app/core/database.py

```python
from motor.motor_asyncio import AsyncIOMotorClient
from beanie import init_beanie
from app.core.config import settings

async def init_db() -> None:
    client = AsyncIOMotorClient(settings.MONGODB_URL)
    from app.models import (
        User, ProviderProfile, ServiceRequest, Proposal,
        Message, Review, Notification, Category,
        Report, AuditLog, BlacklistedToken,
    )
    await init_beanie(
        database=client[settings.DB_NAME],
        document_models=[
            User, ProviderProfile, ServiceRequest, Proposal,
            Message, Review, Notification, Category,
            Report, AuditLog, BlacklistedToken,
        ],
    )
    await _ensure_super_admin(User)

async def _ensure_super_admin(User) -> None:
    """Crée le super admin défini dans .env s'il n'existe pas encore."""
    if not settings.SUPER_ADMIN_EMAIL or not settings.SUPER_ADMIN_PASSWORD:
        return
    from app.models.user import UserRole
    import bcrypt
    existing = await User.find_one(User.email == settings.SUPER_ADMIN_EMAIL)
    if existing:
        if existing.role != UserRole.admin:
            existing.role = UserRole.admin
            existing.is_verified = True
            existing.is_active = True
            await existing.save()
        return
    hashed = bcrypt.hashpw(settings.SUPER_ADMIN_PASSWORD.encode(), bcrypt.gensalt()).decode()
    await User(
        email=settings.SUPER_ADMIN_EMAIL,
        hashed_password=hashed,
        full_name=settings.SUPER_ADMIN_NAME,
        role=UserRole.admin,
        is_verified=True,
        is_active=True,
    ).insert()
    print(f"[startup] Super admin créé : {settings.SUPER_ADMIN_EMAIL}")
```

---

## app/core/security.py

```python
from datetime import datetime, timedelta, timezone
from jose import JWTError, jwt
import bcrypt
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from app.core.config import settings

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")

def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()

def verify_password(plain: str, hashed: str) -> bool:
    return bcrypt.checkpw(plain.encode(), hashed.encode())

def create_access_token(subject: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    return jwt.encode({"sub": subject, "exp": expire}, settings.SECRET_KEY, settings.JWT_ALGORITHM)

def create_refresh_token(subject: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    return jwt.encode({"sub": subject, "exp": expire}, settings.SECRET_KEY, settings.JWT_ALGORITHM)

async def blacklist_token(token: str, user_id: str) -> None:
    """Révoque un token (ban, logout forcé)."""
    from app.models.blacklisted_token import BlacklistedToken
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
        exp = payload.get("exp")
        expires_at = datetime.fromtimestamp(exp, tz=timezone.utc) if exp else datetime.now(timezone.utc) + timedelta(days=1)
    except JWTError:
        expires_at = datetime.now(timezone.utc) + timedelta(days=1)
    await BlacklistedToken(token=token, user_id=user_id, expires_at=expires_at).insert()

async def is_token_blacklisted(token: str) -> bool:
    from app.models.blacklisted_token import BlacklistedToken
    return await BlacklistedToken.find_one(BlacklistedToken.token == token) is not None

async def get_current_user(token: str = Depends(oauth2_scheme)):
    from app.models.user import User
    exc = HTTPException(status.HTTP_401_UNAUTHORIZED, detail="Token invalide ou expiré")
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
        user_id: str = payload.get("sub")
        if not user_id: raise exc
    except JWTError:
        raise exc
    if await is_token_blacklisted(token): raise exc
    user = await User.get(user_id)
    if not user or not user.is_active: raise exc
    if user.is_banned:
        raise HTTPException(status.HTTP_403_FORBIDDEN, detail=f"Compte banni : {user.banned_reason}")
    return user

async def get_admin_user(current_user=Depends(get_current_user)):
    from app.models.user import UserRole
    if current_user.role != UserRole.admin:
        raise HTTPException(status.HTTP_403_FORBIDDEN, detail="Accès admin requis")
    return current_user

async def get_provider_user(current_user=Depends(get_current_user)):
    from app.models.user import UserRole
    if current_user.role not in (UserRole.provider, UserRole.admin):
        raise HTTPException(status.HTTP_403_FORBIDDEN, detail="Accès prestataire requis")
    return current_user
```

---

## Models Beanie — Schémas complets

### user.py
```python
from beanie import Document
from pydantic import EmailStr
from typing import Optional
from datetime import datetime, timezone
from enum import Enum

class UserRole(str, Enum):
    client = "client"
    provider = "provider"
    admin = "admin"

class User(Document):
    email: EmailStr
    phone: Optional[str] = None
    hashed_password: str
    full_name: str
    role: UserRole = UserRole.client
    avatar_url: Optional[str] = None
    is_verified: bool = False
    is_active: bool = True
    # Ban
    is_banned: bool = False
    banned_reason: Optional[str] = None
    banned_at: Optional[datetime] = None
    banned_by: Optional[str] = None           # admin_id
    last_active: Optional[datetime] = None
    # Auth
    refresh_token: Optional[str] = None
    prev_refresh_token: Optional[str] = None  # grace period refresh concurrent
    refresh_token_rotated_at: Optional[datetime] = None
    verification_token: Optional[str] = None
    reset_token: Optional[str] = None
    created_at: datetime = datetime.now(timezone.utc)

    class Settings:
        name = "users"
        indexes = ["email", "phone", "is_banned", "role"]
```

### provider_profile.py
```python
from beanie import Document
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime, timezone
from enum import Enum

class ProviderValidationStatus(str, Enum):
    pending = "pending"
    reviewing = "reviewing"
    waiting_docs = "waiting_docs"
    approved = "approved"
    rejected = "rejected"

class ValidationHistoryEntry(BaseModel):
    status: str
    note: Optional[str] = None
    admin_id: str
    at: datetime = datetime.now(timezone.utc)

class ProviderProfile(Document):
    user_id: str
    bio: Optional[str] = None
    skills: List[str] = []
    categories: List[str] = []
    location: Optional[dict] = None           # {lat, lng, city, address}
    radius_km: float = 20.0
    portfolio: List[str] = []
    certificates: List[str] = []
    avg_rating: float = 0.0
    total_reviews: int = 0
    is_verified_provider: bool = False
    validation_status: ProviderValidationStatus = ProviderValidationStatus.pending
    validation_notes: Optional[str] = None
    id_card_url: Optional[str] = None
    validation_history: List[ValidationHistoryEntry] = []
    updated_at: datetime = datetime.now(timezone.utc)

    class Settings:
        name = "provider_profiles"
        indexes = ["user_id", "validation_status", "is_verified_provider"]
```

### report.py *(NEW)*
```python
from beanie import Document
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime, timezone
from enum import Enum

class ReportType(str, Enum):
    message = "message"; review = "review"
    service_request = "service_request"; user = "user"

class ReportStatus(str, Enum):
    pending = "pending"; reviewing = "reviewing"
    resolved = "resolved"; dismissed = "dismissed"

class ReportSeverity(str, Enum):
    low = "low"; medium = "medium"; high = "high"

class Report(Document):
    reporter_id: str
    target_type: ReportType
    target_id: str
    reason: str
    description: Optional[str] = None
    severity: ReportSeverity = ReportSeverity.medium
    status: ReportStatus = ReportStatus.pending
    moderation_history: List[dict] = []
    resolved_by: Optional[str] = None
    created_at: datetime = datetime.now(timezone.utc)
    updated_at: datetime = datetime.now(timezone.utc)

    class Settings:
        name = "reports"
        indexes = ["reporter_id", "target_id", "status", "severity"]
```

### audit_log.py *(NEW)*
```python
from beanie import Document
from typing import Optional, Dict, Any
from datetime import datetime, timezone

class AuditLog(Document):
    admin_id: str
    admin_email: str
    action: str          # "ban_user", "validate_provider", "delete_review", ...
    target_type: Optional[str] = None
    target_id: Optional[str] = None
    detail: Optional[Dict[str, Any]] = None
    ip_address: Optional[str] = None
    created_at: datetime = datetime.now(timezone.utc)

    class Settings:
        name = "audit_logs"
        indexes = ["admin_id", "action", "created_at"]
```

### blacklisted_token.py *(NEW)*
```python
from beanie import Document
from datetime import datetime, timezone

class BlacklistedToken(Document):
    token: str
    user_id: str
    blacklisted_at: datetime = datetime.now(timezone.utc)
    expires_at: datetime

    class Settings:
        name = "blacklisted_tokens"
        indexes = ["token", "user_id", "expires_at"]
```

### models/\_\_init\_\_.py
```python
from app.models.user import User
from app.models.provider_profile import ProviderProfile
from app.models.service_request import ServiceRequest
from app.models.proposal import Proposal
from app.models.message import Message
from app.models.review import Review
from app.models.notification import Notification
from app.models.category import Category
from app.models.report import Report
from app.models.audit_log import AuditLog
from app.models.blacklisted_token import BlacklistedToken

__all__ = [
    "User", "ProviderProfile", "ServiceRequest", "Proposal",
    "Message", "Review", "Notification", "Category",
    "Report", "AuditLog", "BlacklistedToken",
]
```

---

## schemas/common.py — PyObjectId

```python
from pydantic import BaseModel, BeforeValidator
from typing import Generic, TypeVar, List, Annotated

T = TypeVar("T")

# Convertit ObjectId MongoDB → str lors de la sérialisation Pydantic v2
PyObjectId = Annotated[str, BeforeValidator(str)]

class PaginatedResponse(BaseModel, Generic[T]):
    total: int
    page: int
    limit: int
    data: List[T]

class MessageResponse(BaseModel):
    message: str
```

> **Important :** tous les champs `id`, `user_id`, `client_id`, etc. dans les schemas `*Out` utilisent `PyObjectId` au lieu de `str` pour éviter les `ResponseValidationError` sur les ObjectId MongoDB.

---

## Refresh token — Gestion concurrence

Le refresh utilise une **fenêtre de tolérance de 30 secondes** pour éviter les échecs 401 quand plusieurs requêtes rafraîchissent simultanément :

```
Token actuel reçu          → rotation normale, retourne nouveaux tokens
Ancien token < 30s         → retourne les tokens déjà émis (pas de rotation)
Token inconnu / expiré     → 401
```

Les champs `prev_refresh_token` et `refresh_token_rotated_at` sur `User` stockent l'état de la rotation.

---

## Endpoints — Référence complète

### /auth
| M | Route | Auth | Description |
|---|-------|------|-------------|
| POST | `/auth/register` | ✗ | Inscription (auto-verify en DEBUG) |
| POST | `/auth/login` | ✗ | Connexion → access + refresh tokens |
| POST | `/auth/logout` | ✓ | Révoque le refresh token |
| POST | `/auth/refresh` | ✗ | Renouvelle les tokens (grace period 30s) |
| GET | `/auth/verify-email?token=` | ✗ | Vérification email |
| POST | `/auth/forgot-password` | ✗ | Demande reset MDP |
| POST | `/auth/reset-password` | ✗ | Reset MDP avec token |

### /users
| M | Route | Auth | Description |
|---|-------|------|-------------|
| GET | `/users/me` | ✓ | Profil courant |
| PUT | `/users/me` | ✓ | Modifier son profil |
| DELETE | `/users/me` | ✓ | Supprimer son compte |
| GET | `/users/{id}` | ✓ | Profil d'un utilisateur |
| GET | `/users/providers` | ✓ | Liste prestataires |
| GET | `/users/providers/{id}` | ✓ | Profil prestataire |
| PUT | `/users/providers/me` | ✓ PROVIDER | Modifier profil prestataire |

### /requests
| M | Route | Auth | Description |
|---|-------|------|-------------|
| POST | `/requests` | ✓ | Créer une demande |
| GET | `/requests` | ✓ | Lister les demandes |
| GET | `/requests/nearby` | ✓ | Demandes à proximité (GPS) |
| GET | `/requests/{id}` | ✓ | Détail d'une demande |
| PUT | `/requests/{id}` | ✓ OWNER | Modifier |
| DELETE | `/requests/{id}` | ✓ OWNER | Supprimer |
| PATCH | `/requests/{id}/status` | ✓ | Changer le statut |

### /proposals
| M | Route | Auth | Description |
|---|-------|------|-------------|
| POST | `/proposals` | ✓ PROVIDER | Soumettre une offre |
| GET | `/proposals/request/{req_id}` | ✓ | Offres pour une demande |
| GET | `/proposals/mine` | ✓ PROVIDER | Mes offres |
| POST | `/proposals/{id}/accept` | ✓ OWNER | Accepter une offre |
| POST | `/proposals/{id}/decline` | ✓ OWNER | Refuser une offre |
| DELETE | `/proposals/{id}` | ✓ PROVIDER | Supprimer son offre |

### /messages
| M | Route | Auth | Description |
|---|-------|------|-------------|
| GET | `/messages/conversations` | ✓ | Liste conversations |
| GET | `/messages/{room_id}/history` | ✓ | Historique messages |
| POST | `/messages/{room_id}` | ✓ | Envoyer un message |
| PATCH | `/messages/{room_id}/read` | ✓ | Marquer comme lu |

### /ws
| Proto | Route | Auth |
|-------|-------|------|
| WS | `/ws/chat/{room_id}?token=JWT` | ✓ JWT query param |

### /reviews
| M | Route | Auth | Description |
|---|-------|------|-------------|
| POST | `/reviews` | ✓ | Laisser un avis |
| GET | `/reviews/provider/{id}` | ✓ | Avis d'un prestataire |
| DELETE | `/reviews/{id}` | ✓ OWNER | Supprimer son avis |

### /notifications
| M | Route | Auth | Description |
|---|-------|------|-------------|
| GET | `/notifications` | ✓ | Liste notifications |
| PATCH | `/notifications/{id}/read` | ✓ | Marquer comme lue |
| PATCH | `/notifications/read-all` | ✓ | Tout marquer comme lu |
| GET | `/notifications/unread-count` | ✓ | Compteur non lues |

### /categories
| M | Route | Auth |
|---|-------|------|
| GET | `/categories` | ✗ |
| GET | `/categories/{id}` | ✗ |

### /uploads
| M | Route | Auth |
|---|-------|------|
| POST | `/uploads/image` | ✓ |
| DELETE | `/uploads/{id}` | ✓ OWNER |

### /admin *(tous les endpoints requièrent `role=admin`)*
| M | Route | Description |
|---|-------|-------------|
| GET | `/admin/stats` | Dashboard : compteurs globaux |
| GET | `/admin/users` | Liste users (filtres: role, is_banned, search) |
| GET | `/admin/users/{id}` | Détail user + profil + nb demandes |
| POST | `/admin/users/{id}/ban` | Bannir un utilisateur |
| POST | `/admin/users/{id}/unban` | Débannir |
| PATCH | `/admin/users/{id}/role` | Changer le rôle |
| GET | `/admin/users/export/csv` | Export CSV utilisateurs |
| GET | `/admin/providers/validation` | Prestataires en attente de validation |
| PATCH | `/admin/providers/{id}/validation` | Mettre à jour le statut de validation |
| GET | `/admin/reports` | Liste signalements |
| PATCH | `/admin/reports/{id}/resolve` | Résoudre un signalement |
| PATCH | `/admin/reports/{id}/dismiss` | Ignorer un signalement |
| DELETE | `/admin/reviews/{id}` | Supprimer un avis (modération) |
| PATCH | `/admin/requests/{id}/close` | Fermer une demande de service |
| POST | `/admin/categories` | Créer une catégorie |
| PATCH | `/admin/categories/{id}` | Modifier une catégorie |
| DELETE | `/admin/categories/{id}` | Supprimer une catégorie |
| POST | `/admin/notifications/broadcast` | Envoyer notification groupée |
| GET | `/admin/audit-logs` | Journal des actions admin |
| DELETE | `/admin/tokens/cleanup` | Nettoyer les tokens expirés |

---

## Panel Admin UI — `/admin-panel`

Interface starlette-admin montée sur `/admin-panel`, protégée par session.

**Connexion :** email + mot de passe d'un compte avec `role=admin`

**Vues disponibles :**
```
📁 Utilisateurs
   ├── Clients
   ├── Prestataires
   └── Administrateurs
📋 Profils prestataires
🏷️ Catégories
🚩 Signalements         (lecture + édition statut uniquement)
📜 Audit Logs           (lecture seule)
```

---

## WebSocket — ConnectionManager

```python
# app/websocket/manager.py
from fastapi import WebSocket
from collections import defaultdict
from typing import Dict, List

class ConnectionManager:
    def __init__(self):
        self.rooms: Dict[str, List[WebSocket]] = defaultdict(list)

    async def connect(self, room_id: str, ws: WebSocket):
        await ws.accept()
        self.rooms[room_id].append(ws)

    def disconnect(self, room_id: str, ws: WebSocket):
        self.rooms[room_id].remove(ws)

    async def send_to_room(self, room_id: str, data: dict):
        for ws in self.rooms.get(room_id, []):
            await ws.send_json(data)

manager = ConnectionManager()
```

**Format message WS (JSON) :**
```json
{
  "type": "text",
  "content": "Bonjour, êtes-vous disponible ?",
  "media_url": null,
  "room_id": "abc123",
  "sender_id": "665f...",
  "timestamp": "2026-05-16T10:30:00Z"
}
```

---

## Géolocalisation — Haversine Python pur

```python
import math

def haversine_distance(lat1, lng1, lat2, lng2) -> float:
    R = 6371.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lng2 - lng1)
    a = math.sin(dphi/2)**2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda/2)**2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
```

---

## Dépendances FastAPI — Injection

```python
# Utilisateur connecté (vérifie blacklist + ban)
async def get_current_user(token: str = Depends(oauth2_scheme)) -> User: ...

# Admin uniquement
async def get_admin_user(user = Depends(get_current_user)) -> User:
    if user.role != "admin": raise HTTPException(403)
    return user

# Prestataire ou admin
async def get_provider_user(user = Depends(get_current_user)) -> User:
    if user.role not in ("provider", "admin"): raise HTTPException(403)
    return user

# Paramètre pagination réutilisable
async def paginate(query, page: int = 1, limit: int = 20) -> PaginatedResponse: ...
```

---

## Lancement

```bash
# Installation
pip install -r requirements.txt

# Développement (auto-reload)
uvicorn app.main:app --reload --port 8000

# Production
uvicorn app.main:app --workers 4 --port 8000

# Exporter la doc OpenAPI
curl http://localhost:8000/openapi.json -o openapi.json
```

**URLs utiles :**
- Swagger UI : http://localhost:8000/docs
- ReDoc : http://localhost:8000/redoc
- OpenAPI JSON : http://localhost:8000/openapi.json
- Panel Admin : http://localhost:8000/admin-panel

---

## Problèmes connus & solutions

| Erreur | Cause | Solution |
|--------|-------|----------|
| `bson.binary ModuleNotFoundError` | Package `bson` standalone installé | `pip uninstall bson` |
| `append_metadata error` (Beanie) | Beanie 2.x incompatible Motor | Pinner `beanie==1.26.0` |
| `passlib AttributeError` (bcrypt) | passlib 1.7.4 incompatible bcrypt 4/5 | Utiliser `bcrypt` directement |
| `ResponseValidationError` sur ObjectId | ObjectId non sérialisable | `PyObjectId` dans schemas + `ENCODERS_BY_TYPE[ObjectId]=str` |
| `ZoneInfoNotFoundError: UTC` | `tzdata` absent sur Windows | `pip install tzdata` |
| `itsdangerous ModuleNotFoundError` | Requis par `SessionMiddleware` | `pip install itsdangerous` |
| `bool not callable` (starlette-admin) | `can_delete = False` écrase la méthode | Surcharger comme méthode : `def can_delete(self, r): return False` |


---

## Stack & Versions

```
fastapi>=0.111.0
uvicorn[standard]>=0.29.0
motor>=3.4.0
beanie>=1.26.0
pydantic[email]>=2.7.0
pydantic-settings>=2.2.0
python-jose[cryptography]>=3.3.0
passlib[bcrypt]>=1.7.4
aiosmtplib>=3.0.0
python-multipart>=0.0.9
aiofiles>=23.2.1
python-dotenv>=1.0.1
# dev
pytest>=8.2.0
pytest-asyncio>=0.23.0
httpx>=0.27.0
```

---

## Structure des fichiers

```
services-app/
├── .env
├── .env.example
├── requirements.txt
├── requirements-dev.txt
│
├── app/
│   ├── main.py                     # lifespan, CORS, montage routeurs, StaticFiles
│   │
│   ├── core/
│   │   ├── config.py               # Settings (pydantic-settings)
│   │   ├── database.py             # init Beanie + Motor client
│   │   ├── security.py             # JWT, bcrypt, get_current_user
│   │   ├── email.py                # SMTP async (aiosmtplib)
│   │   └── exceptions.py           # handlers HTTP globaux
│   │
│   ├── models/
│   │   ├── __init__.py             # exporte tous les Documents → init Beanie
│   │   ├── user.py
│   │   ├── provider_profile.py
│   │   ├── service_request.py
│   │   ├── proposal.py
│   │   ├── message.py
│   │   ├── review.py
│   │   ├── notification.py
│   │   └── category.py
│   │
│   ├── schemas/
│   │   ├── auth.py
│   │   ├── user.py
│   │   ├── service_request.py
│   │   ├── proposal.py
│   │   ├── message.py
│   │   ├── review.py
│   │   ├── notification.py
│   │   ├── category.py
│   │   └── common.py               # PaginatedResponse, MessageResponse, ErrorResponse
│   │
│   ├── routers/
│   │   ├── auth.py
│   │   ├── users.py
│   │   ├── requests.py
│   │   ├── proposals.py
│   │   ├── messages.py
│   │   ├── websocket.py
│   │   ├── reviews.py
│   │   ├── notifications.py
│   │   ├── categories.py
│   │   ├── uploads.py
│   │   └── admin.py
│   │
│   ├── services/
│   │   ├── auth_service.py
│   │   ├── user_service.py
│   │   ├── request_service.py
│   │   ├── proposal_service.py
│   │   ├── message_service.py
│   │   ├── review_service.py
│   │   ├── notification_service.py
│   │   ├── file_service.py
│   │   └── geo_service.py
│   │
│   ├── websocket/
│   │   ├── manager.py
│   │   └── handlers.py
│   │
│   └── utils/
│       ├── pagination.py
│       ├── validators.py
│       └── helpers.py
│
├── uploads/
│   ├── avatars/
│   ├── portfolio/
│   ├── requests/
│   ├── messages/
│   └── certificates/
│
└── tests/
    ├── conftest.py
    ├── test_auth.py
    ├── test_requests.py
    └── test_proposals.py
```

---

## Variables d'environnement (.env)

```env
APP_NAME="Services à la Demande"
APP_ENV=development
DEBUG=true
SECRET_KEY="change-me-to-a-long-random-string-minimum-32-chars"
CORS_ORIGINS="http://localhost:3000,http://localhost:8081"

MONGODB_URL=mongodb+srv://user:password@cluster0.xxxxx.mongodb.net/?appName=Cluster0
DB_NAME=services_app

JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=15
REFRESH_TOKEN_EXPIRE_DAYS=7

UPLOAD_DIR=./uploads
MAX_FILE_SIZE_MB=10
STATIC_URL="http://localhost:8000/static"

SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER="ton.email@gmail.com"
SMTP_PASSWORD="ton-app-password-gmail"
EMAIL_FROM="Services App <ton.email@gmail.com>"

PUSH_NOTIFICATIONS_ENABLED=false
SMS_ENABLED=false
GOOGLE_OAUTH_ENABLED=false
GOOGLE_MAPS_ENABLED=false
OCR_ENABLED=false
CLOUD_STORAGE_ENABLED=false
REDIS_ENABLED=false
```

---

## app/main.py — Point d'entrée

```python
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from app.core.config import settings
from app.core.database import init_db
from app.routers import auth, users, requests, proposals, messages, websocket, \
                        reviews, notifications, categories, uploads, admin

@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()           # connexion MongoDB + init Beanie
    yield

app = FastAPI(title=settings.APP_NAME, lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS.split(","),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/static", StaticFiles(directory=settings.UPLOAD_DIR), name="static")

app.include_router(auth.router,          prefix="/auth",          tags=["Auth"])
app.include_router(users.router,         prefix="/users",         tags=["Users"])
app.include_router(requests.router,      prefix="/requests",      tags=["Requests"])
app.include_router(proposals.router,     prefix="/proposals",     tags=["Proposals"])
app.include_router(messages.router,      prefix="/messages",      tags=["Messages"])
app.include_router(websocket.router,     prefix="/ws",            tags=["WebSocket"])
app.include_router(reviews.router,       prefix="/reviews",       tags=["Reviews"])
app.include_router(notifications.router, prefix="/notifications", tags=["Notifications"])
app.include_router(categories.router,    prefix="/categories",    tags=["Categories"])
app.include_router(uploads.router,       prefix="/uploads",       tags=["Uploads"])
app.include_router(admin.router,         prefix="/admin",         tags=["Admin"])
```

---

## app/core/config.py

```python
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    APP_NAME: str
    APP_ENV: str = "development"
    DEBUG: bool = True
    SECRET_KEY: str
    CORS_ORIGINS: str = "http://localhost:3000"

    MONGODB_URL: str
    DB_NAME: str

    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    UPLOAD_DIR: str = "./uploads"
    MAX_FILE_SIZE_MB: int = 10
    STATIC_URL: str = "http://localhost:8000/static"

    SMTP_HOST: str
    SMTP_PORT: int = 587
    SMTP_USER: str
    SMTP_PASSWORD: str
    EMAIL_FROM: str

    PUSH_NOTIFICATIONS_ENABLED: bool = False
    SMS_ENABLED: bool = False
    GOOGLE_OAUTH_ENABLED: bool = False
    GOOGLE_MAPS_ENABLED: bool = False
    OCR_ENABLED: bool = False
    CLOUD_STORAGE_ENABLED: bool = False
    REDIS_ENABLED: bool = False

    class Config:
        env_file = ".env"

settings = Settings()
```

---

## app/core/database.py

```python
from motor.motor_asyncio import AsyncIOMotorClient
from beanie import init_beanie
from app.core.config import settings
from app.models import (
    User, ProviderProfile, ServiceRequest, Proposal,
    Message, Review, Notification, Category
)

async def init_db():
    client = AsyncIOMotorClient(settings.MONGODB_URL)
    await init_beanie(
        database=client[settings.DB_NAME],
        document_models=[
            User, ProviderProfile, ServiceRequest, Proposal,
            Message, Review, Notification, Category
        ]
    )
```

---

## app/core/security.py

```python
from datetime import datetime, timedelta, timezone
from typing import Optional
from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from app.core.config import settings
from app.models.user import User

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)

def create_access_token(subject: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    return jwt.encode({"sub": subject, "exp": expire}, settings.SECRET_KEY, settings.JWT_ALGORITHM)

def create_refresh_token(subject: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    return jwt.encode({"sub": subject, "exp": expire}, settings.SECRET_KEY, settings.JWT_ALGORITHM)

async def get_current_user(token: str = Depends(oauth2_scheme)) -> User:
    credentials_exc = HTTPException(status.HTTP_401_UNAUTHORIZED, "Token invalide")
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
        user_id: str = payload.get("sub")
        if not user_id:
            raise credentials_exc
    except JWTError:
        raise credentials_exc
    user = await User.get(user_id)
    if not user or not user.is_active:
        raise credentials_exc
    return user

async def get_admin_user(current_user: User = Depends(get_current_user)) -> User:
    if current_user.role != "admin":
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Accès admin requis")
    return current_user
```

---

## Models Beanie — Schémas complets

### user.py
```python
from beanie import Document
from pydantic import EmailStr
from typing import Optional
from datetime import datetime, timezone
from enum import Enum

class UserRole(str, Enum):
    client = "client"
    provider = "provider"
    admin = "admin"

class User(Document):
    email: EmailStr
    phone: Optional[str] = None
    hashed_password: str
    full_name: str
    role: UserRole = UserRole.client
    avatar_url: Optional[str] = None
    is_verified: bool = False
    is_active: bool = True
    refresh_token: Optional[str] = None
    verification_token: Optional[str] = None
    reset_token: Optional[str] = None
    created_at: datetime = datetime.now(timezone.utc)

    class Settings:
        name = "users"
        indexes = ["email", "phone"]
```

### provider_profile.py
```python
from beanie import Document, Link
from pydantic import BaseModel
from typing import Optional, List
from app.models.user import User

class Location(BaseModel):
    lat: float
    lng: float
    city: Optional[str] = None
    address: Optional[str] = None

class ProviderProfile(Document):
    user_id: str                        # référence User._id
    bio: Optional[str] = None
    skills: List[str] = []
    categories: List[str] = []         # liste de Category._id (str)
    location: Optional[Location] = None
    radius_km: float = 20.0
    portfolio: List[str] = []          # URLs images
    certificates: List[str] = []       # URLs justificatifs
    avg_rating: float = 0.0
    total_reviews: int = 0
    is_verified_provider: bool = False

    class Settings:
        name = "provider_profiles"
        indexes = ["user_id"]
```

### service_request.py
```python
from beanie import Document
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime, timezone
from enum import Enum

class Urgency(str, Enum):
    low = "low"
    medium = "medium"
    high = "high"

class RequestStatus(str, Enum):
    open = "open"
    in_progress = "in_progress"
    done = "done"
    cancelled = "cancelled"

class GeoLocation(BaseModel):
    lat: float
    lng: float
    address: Optional[str] = None

class ServiceRequest(Document):
    client_id: str
    category_id: str
    title: str
    description: str
    photos: List[str] = []
    location: Optional[GeoLocation] = None
    urgency: Urgency = Urgency.medium
    status: RequestStatus = RequestStatus.open
    created_at: datetime = datetime.now(timezone.utc)
    updated_at: datetime = datetime.now(timezone.utc)

    class Settings:
        name = "service_requests"
        indexes = ["client_id", "status", "category_id"]
```

### proposal.py
```python
from beanie import Document
from typing import Optional
from datetime import datetime, timezone
from enum import Enum

class ProposalStatus(str, Enum):
    pending = "pending"
    accepted = "accepted"
    declined = "declined"

class Proposal(Document):
    request_id: str
    provider_id: str
    message: str
    price_estimate: Optional[float] = None
    status: ProposalStatus = ProposalStatus.pending
    created_at: datetime = datetime.now(timezone.utc)

    class Settings:
        name = "proposals"
        indexes = ["request_id", "provider_id"]
```

### message.py
```python
from beanie import Document
from typing import Optional
from datetime import datetime, timezone

class Message(Document):
    room_id: str
    sender_id: str
    content: str
    media_url: Optional[str] = None
    is_read: bool = False
    created_at: datetime = datetime.now(timezone.utc)

    class Settings:
        name = "messages"
        indexes = ["room_id", "sender_id"]
```

### review.py
```python
from beanie import Document
from typing import Optional
from datetime import datetime, timezone
from pydantic import Field

class Review(Document):
    request_id: str
    reviewer_id: str
    provider_id: str
    rating: int = Field(..., ge=1, le=5)
    comment: Optional[str] = None
    created_at: datetime = datetime.now(timezone.utc)

    class Settings:
        name = "reviews"
        indexes = ["provider_id", "reviewer_id"]
```

### notification.py
```python
from beanie import Document
from typing import Optional
from datetime import datetime, timezone

class Notification(Document):
    user_id: str
    type: str                           # "new_proposal" | "accepted" | "message" | ...
    title: str
    body: str
    is_read: bool = False
    ref_id: Optional[str] = None        # id de l'objet concerné
    created_at: datetime = datetime.now(timezone.utc)

    class Settings:
        name = "notifications"
        indexes = ["user_id", "is_read"]
```

### category.py
```python
from beanie import Document

class Category(Document):
    name: str
    slug: str
    icon: str = ""
    is_active: bool = True

    class Settings:
        name = "categories"
        indexes = ["slug"]
```

### models/\_\_init\_\_.py
```python
from app.models.user import User
from app.models.provider_profile import ProviderProfile
from app.models.service_request import ServiceRequest
from app.models.proposal import Proposal
from app.models.message import Message
from app.models.review import Review
from app.models.notification import Notification
from app.models.category import Category

__all__ = [
    "User", "ProviderProfile", "ServiceRequest", "Proposal",
    "Message", "Review", "Notification", "Category"
]
```

---

## Schemas Pydantic v2 — Référence rapide

### schemas/common.py
```python
from pydantic import BaseModel
from typing import Generic, TypeVar, List

T = TypeVar("T")

class PaginatedResponse(BaseModel, Generic[T]):
    total: int
    page: int
    limit: int
    data: List[T]

class MessageResponse(BaseModel):
    message: str

class ErrorResponse(BaseModel):
    detail: str
```

### schemas/auth.py
```python
from pydantic import BaseModel, EmailStr

class RegisterRequest(BaseModel):
    email: EmailStr
    password: str
    full_name: str
    phone: str | None = None
    role: str = "client"               # "client" | "provider"

class LoginRequest(BaseModel):
    email: EmailStr
    password: str

class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"

class RefreshRequest(BaseModel):
    refresh_token: str
```

---

## Endpoints — Référence complète

### /auth
| M | Route | Auth | Service |
|---|-------|------|---------|
| POST | `/auth/register` | ✗ | `auth_service.register()` |
| POST | `/auth/login` | ✗ | `auth_service.login()` |
| POST | `/auth/logout` | ✓ | `auth_service.logout()` |
| POST | `/auth/refresh` | ✗ | `auth_service.refresh_token()` |
| GET | `/auth/verify-email?token=` | ✗ | `auth_service.verify_email()` |
| POST | `/auth/forgot-password` | ✗ | `auth_service.forgot_password()` |
| POST | `/auth/reset-password` | ✗ | `auth_service.reset_password()` |

### /users
| M | Route | Auth | Service |
|---|-------|------|---------|
| GET | `/users/me` | ✓ | `user_service.get_me()` |
| PUT | `/users/me` | ✓ | `user_service.update_me()` |
| DELETE | `/users/me` | ✓ | `user_service.delete_me()` |
| GET | `/users/{id}` | ✓ | `user_service.get_user()` |
| GET | `/users/providers` | ✓ | `user_service.list_providers()` |
| GET | `/users/providers/{id}` | ✓ | `user_service.get_provider()` |
| PUT | `/users/providers/me` | ✓ PROVIDER | `user_service.update_provider()` |

### /requests
| M | Route | Auth | Service |
|---|-------|------|---------|
| POST | `/requests` | ✓ | `request_service.create()` |
| GET | `/requests` | ✓ | `request_service.list()` |
| GET | `/requests/nearby` | ✓ | `request_service.get_nearby()` |
| GET | `/requests/{id}` | ✓ | `request_service.get_one()` |
| PUT | `/requests/{id}` | ✓ OWNER | `request_service.update()` |
| DELETE | `/requests/{id}` | ✓ OWNER | `request_service.delete()` |
| PATCH | `/requests/{id}/status` | ✓ | `request_service.update_status()` |

### /proposals
| M | Route | Auth | Service |
|---|-------|------|---------|
| POST | `/proposals` | ✓ PROVIDER | `proposal_service.submit()` |
| GET | `/proposals/request/{req_id}` | ✓ | `proposal_service.list_by_request()` |
| GET | `/proposals/mine` | ✓ PROVIDER | `proposal_service.my_proposals()` |
| POST | `/proposals/{id}/accept` | ✓ OWNER | `proposal_service.accept()` |
| POST | `/proposals/{id}/decline` | ✓ OWNER | `proposal_service.decline()` |
| DELETE | `/proposals/{id}` | ✓ PROVIDER | `proposal_service.delete()` |

### /messages
| M | Route | Auth | Service |
|---|-------|------|---------|
| GET | `/messages/conversations` | ✓ | `message_service.get_conversations()` |
| GET | `/messages/{room_id}/history` | ✓ | `message_service.get_history()` |
| POST | `/messages/{room_id}` | ✓ | `message_service.send()` |
| PATCH | `/messages/{room_id}/read` | ✓ | `message_service.mark_read()` |

### /ws
| Proto | Route | Auth |
|-------|-------|------|
| WS | `/ws/chat/{room_id}?token=JWT` | ✓ JWT query param |

### /reviews
| M | Route | Auth | Service |
|---|-------|------|---------|
| POST | `/reviews` | ✓ | `review_service.create()` |
| GET | `/reviews/provider/{id}` | ✓ | `review_service.get_by_provider()` |
| DELETE | `/reviews/{id}` | ✓ OWNER | `review_service.delete()` |

### /notifications
| M | Route | Auth | Service |
|---|-------|------|---------|
| GET | `/notifications` | ✓ | `notification_service.list()` |
| PATCH | `/notifications/{id}/read` | ✓ | `notification_service.mark_read()` |
| PATCH | `/notifications/read-all` | ✓ | `notification_service.mark_all_read()` |
| GET | `/notifications/unread-count` | ✓ | `notification_service.unread_count()` |

### /categories
| M | Route | Auth | Service |
|---|-------|------|---------|
| GET | `/categories` | ✗ | `Category.find(is_active=True).to_list()` |
| GET | `/categories/{id}` | ✗ | `Category.get(id)` |

### /uploads
| M | Route | Auth | Service |
|---|-------|------|---------|
| POST | `/uploads/image` | ✓ | `file_service.save_upload()` |
| DELETE | `/uploads/{id}` | ✓ OWNER | `file_service.delete_file()` |

### /admin
| M | Route | Auth |
|---|-------|------|
| GET | `/admin/users` | ✓ ADMIN |
| POST | `/admin/users/{id}/ban` | ✓ ADMIN |
| POST | `/admin/providers/{id}/verify` | ✓ ADMIN |
| GET | `/admin/stats` | ✓ ADMIN |
| POST | `/admin/categories` | ✓ ADMIN |
| DELETE | `/admin/categories/{id}` | ✓ ADMIN |

---

## WebSocket — ConnectionManager

```python
# app/websocket/manager.py
from fastapi import WebSocket
from collections import defaultdict
from typing import Dict, List

class ConnectionManager:
    def __init__(self):
        self.rooms: Dict[str, List[WebSocket]] = defaultdict(list)

    async def connect(self, room_id: str, ws: WebSocket):
        await ws.accept()
        self.rooms[room_id].append(ws)

    def disconnect(self, room_id: str, ws: WebSocket):
        self.rooms[room_id].remove(ws)

    async def send_to_room(self, room_id: str, data: dict):
        for ws in self.rooms.get(room_id, []):
            await ws.send_json(data)

manager = ConnectionManager()
```

```python
# app/routers/websocket.py
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query
from app.core.security import get_current_user_ws
from app.websocket.manager import manager
from app.websocket.handlers import handle_message

router = APIRouter()

@router.websocket("/chat/{room_id}")
async def ws_chat(room_id: str, ws: WebSocket, token: str = Query(...)):
    user = await get_current_user_ws(token)  # lève une erreur si token invalide
    await manager.connect(room_id, ws)
    try:
        while True:
            data = await ws.receive_json()
            await handle_message(room_id, user, data, manager)
    except WebSocketDisconnect:
        manager.disconnect(room_id, ws)
```

**Format message WS (JSON) :**
```json
{
  "type": "text",
  "content": "Bonjour, êtes-vous disponible ?",
  "media_url": null,
  "room_id": "abc123",
  "sender_id": "665f...",
  "timestamp": "2026-05-16T10:30:00Z"
}
```

---

## Géolocalisation — Haversine Python pur

```python
# app/services/geo_service.py
import math

def haversine_distance(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Retourne la distance en kilomètres entre deux points GPS."""
    R = 6371.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lng2 - lng1)
    a = math.sin(dphi / 2)**2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2)**2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

def filter_nearby(items: list, user_lat: float, user_lng: float, radius_km: float) -> list:
    """Filtre une liste d'objets ayant un champ location.lat / location.lng."""
    return [
        item for item in items
        if item.location and
        haversine_distance(user_lat, user_lng, item.location.lat, item.location.lng) <= radius_km
    ]
```

---

## Stockage fichiers

```python
# app/services/file_service.py
import aiofiles, uuid, os
from fastapi import UploadFile, HTTPException
from app.core.config import settings

ALLOWED_TYPES = {"image/jpeg", "image/png", "image/webp"}
FOLDERS = {"avatar": "avatars", "portfolio": "portfolio",
           "request": "requests", "message": "messages", "certificate": "certificates"}

async def save_upload(file: UploadFile, file_type: str) -> str:
    if file.content_type not in ALLOWED_TYPES:
        raise HTTPException(400, "Type de fichier non autorisé")
    max_bytes = settings.MAX_FILE_SIZE_MB * 1024 * 1024
    content = await file.read()
    if len(content) > max_bytes:
        raise HTTPException(400, f"Fichier trop lourd (max {settings.MAX_FILE_SIZE_MB} Mo)")
    folder = FOLDERS.get(file_type, "avatars")
    ext = file.filename.rsplit(".", 1)[-1]
    filename = f"{uuid.uuid4().hex}.{ext}"
    path = os.path.join(settings.UPLOAD_DIR, folder, filename)
    async with aiofiles.open(path, "wb") as f:
        await f.write(content)
    return f"{settings.STATIC_URL}/{folder}/{filename}"
```

---

## Pagination Beanie

```python
# app/utils/pagination.py
from beanie import Document
from app.schemas.common import PaginatedResponse

async def paginate(query, page: int = 1, limit: int = 20) -> PaginatedResponse:
    skip = (page - 1) * limit
    total = await query.count()
    data = await query.skip(skip).limit(limit).to_list()
    return PaginatedResponse(total=total, page=page, limit=limit, data=data)
```

---

## Helpers utilitaires

```python
# app/utils/helpers.py
import secrets, hashlib

def generate_room_id(uid_a: str, uid_b: str) -> str:
    """Génère un room_id stable et symétrique depuis deux IDs utilisateurs."""
    pair = sorted([str(uid_a), str(uid_b)])
    return hashlib.sha256("".join(pair).encode()).hexdigest()[:32]

def generate_token(length: int = 32) -> str:
    """Token sécurisé pour vérification email / reset MDP."""
    return secrets.token_urlsafe(length)
```

---

## Dépendances FastAPI — Injection

```python
# Utilisateur connecté quelconque
async def get_current_user(token: str = Depends(oauth2_scheme)) -> User: ...

# Admin uniquement
async def get_admin_user(user: User = Depends(get_current_user)) -> User:
    if user.role != "admin": raise HTTPException(403)
    return user

# Prestataire uniquement
async def get_provider_user(user: User = Depends(get_current_user)) -> User:
    if user.role != "provider": raise HTTPException(403)
    return user

# Paramètre pagination réutilisable
def pagination_params(page: int = 1, limit: int = 20):
    return {"page": page, "limit": min(limit, 100)}
```

---

## Lancement

```bash
# Installation
pip install -r requirements.txt

# Développement (auto-reload)
uvicorn app.main:app --reload --port 8000

# Production
uvicorn app.main:app --workers 4 --port 8000

# Tests
pytest tests/ -v --asyncio-mode=auto
```

**Docs auto :** http://localhost:8000/docs
