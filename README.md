# Services à la Demande — API FastAPI

> **Projet de fin de Licence — KIEMTORE Bienvenue**  
> Plateforme de mise en relation entre particuliers et prestataires de services · Version Starter 1.0 · 100 % gratuit

---

## Table des matières

1. [Contexte & Problématique](#1-contexte--problématique)
2. [La Solution](#2-la-solution)
3. [Fonctionnalités](#3-fonctionnalités)
4. [Stack Technique](#4-stack-technique)
5. [Architecture du projet](#5-architecture-du-projet)
6. [Structure des fichiers](#6-structure-des-fichiers)
7. [Modèles de données (MongoDB)](#7-modèles-de-données-mongodb)
8. [Endpoints API](#8-endpoints-api)
9. [Authentification & Sécurité](#9-authentification--sécurité)
10. [WebSocket — Messagerie temps réel](#10-websocket--messagerie-temps-réel)
11. [Stockage local des fichiers](#11-stockage-local-des-fichiers)
12. [Variables d'environnement (.env)](#12-variables-denvironnement-env)
13. [Dépendances Python](#13-dépendances-python)
14. [Installation & Lancement](#14-installation--lancement)
15. [Feature Flags — Services désactivés (Starter)](#15-feature-flags--services-désactivés-starter)
16. [Planning de développement](#16-planning-de-développement)

---

## 1. Contexte & Problématique

Dans la vie quotidienne, trouver rapidement un prestataire de confiance (électricien, plombier, menuisier…) reste un défi majeur :

- **Manque de réseau** : peu de personnes connaissent des professionnels qualifiés à proximité
- **Urgence** : les besoins sont souvent imprévus et nécessitent une intervention rapide
- **Difficulté de recherche** : les annuaires traditionnels ne permettent pas une mise en relation directe
- **Confiance** : difficile d'évaluer la fiabilité d'un prestataire inconnu

**Problématique :**  
> *Comment faciliter la mise en relation rapide, simple et sécurisée entre particuliers ayant un besoin de service et prestataires qualifiés disponibles à proximité ?*

---

## 2. La Solution

L'application **inverse le modèle traditionnel** : au lieu de chercher un prestataire, **l'utilisateur publie son besoin** et les prestataires viennent à lui.

### Exemple d'utilisation

1. Marie publie : *"Besoin d'un électricien pour remplacer 5 ampoules — Ouagadougou, secteur 15"*
2. Plusieurs électriciens de sa zone voient la demande et proposent leurs services avec un prix estimatif
3. Marie consulte les profils et avis, choisit Ahmed
4. Ils échangent via la messagerie intégrée pour confirmer le rendez-vous
5. Ahmed réalise la prestation
6. Marie note et commente la prestation

---

## 3. Fonctionnalités

### Pour les utilisateurs (demandeurs)
- Publication de besoins avec description, photos, localisation, degré d'urgence
- Réception de propositions avec notifications
- Consultation des profils prestataires (qualifications, avis, portfolio)
- Messagerie intégrée temps réel (WebSocket)
- Suivi d'état des demandes (en attente → en cours → terminée)
- Système de notation et commentaires

### Pour les prestataires
- Fil d'actualité des demandes par catégorie et zone géographique
- Filtres : type de service, localisation, urgence
- Envoi de propositions avec devis estimatif
- Profil professionnel : portfolio, certifications, spécialités, zone d'intervention
- Gestion des missions acceptées
- Tableau de bord : nombre de missions, évaluation moyenne

### Fonctionnalités communes
- Authentification sécurisée (JWT — Access + Refresh token)
- Vérification d'email (lien SMTP)
- Réinitialisation de mot de passe
- Notifications in-app
- Géolocalisation par calcul Haversine (sans Google Maps)
- Back-office Admin (ban, vérification prestataires, catégories, stats)

### Catégories de services couvertes
| # | Catégorie |
|---|-----------|
| 1 | Bâtiment & réparations (électricité, plomberie, menuiserie, peinture) |
| 2 | Entretien de la maison (ménage, jardinage, nettoyage) |
| 3 | Déménagement & transport |
| 4 | Événements (traiteurs, photographes, DJ, décorateurs) |
| 5 | Bien-être (coiffure à domicile, esthétique) |
| 6 | Cours & formation (soutien scolaire, langues, musique) |
| 7 | Informatique (réparation, installation, dépannage) |

---

## 4. Stack Technique

| Couche | Technologie | Rôle |
|--------|------------|------|
| **Framework** | FastAPI | API REST + WebSocket |
| **Base de données** | MongoDB Atlas | Stockage NoSQL cloud (gratuit) |
| **ODM** | Beanie (Motor) | Mapping async Python ↔ MongoDB |
| **Validation** | Pydantic v2 | Schémas de validation entrée/sortie |
| **Auth** | JWT (python-jose) + bcrypt | Tokens Access/Refresh, hashage mots de passe |
| **Email** | SMTP (aiosmtplib) | Vérification email, reset mot de passe |
| **WebSocket** | FastAPI natif | Messagerie temps réel |
| **Fichiers** | StaticFiles FastAPI | Stockage local `/uploads/`, servi sur `/static` |
| **Géo** | Python pur (Haversine) | Calcul distance, filtrage proximité |
| **Config** | pydantic-settings | Variables d'environnement via `.env` |
| **Tests** | pytest + httpx | Tests unitaires et d'intégration |

> **Version Starter** : aucune dépendance payante. Redis, Google Maps, Firebase, Twilio sont prévus mais désactivés via feature flags.

---

## 5. Architecture du projet

```
Client (Mobile/Web)
        │
        ▼
   FastAPI App (main.py)
   ├── CORS Middleware
   ├── Lifespan → connexion MongoDB Atlas (Beanie init)
   ├── StaticFiles → /static → ./uploads/
        │
        ├── Routers  ──────────────────────────────────────────────
        │   ├── /auth          → AuthRouter
        │   ├── /users         → UsersRouter
        │   ├── /requests      → RequestsRouter
        │   ├── /proposals     → ProposalsRouter
        │   ├── /messages      → MessagesRouter
        │   ├── /ws/chat/{id}  → WebSocketRouter
        │   ├── /reviews       → ReviewsRouter
        │   ├── /notifications → NotificationsRouter
        │   ├── /categories    → CategoriesRouter
        │   ├── /uploads       → UploadsRouter
        │   └── /admin         → AdminRouter
        │
        ├── Services (logique métier pure)
        │   ├── auth_service   proposal_service   notification_service
        │   ├── user_service   message_service    file_service
        │   ├── request_service review_service    geo_service
        │
        ├── Models (Beanie Documents → collections MongoDB)
        │   ├── User            ServiceRequest    Review
        │   ├── ProviderProfile Proposal          Notification
        │   ├── Message         Category
        │
        ├── Schemas (Pydantic v2 — validation API, pas BDD)
        │
        └── Core
            ├── config.py      → Settings (pydantic-settings)
            ├── database.py    → init Beanie + MongoDB
            ├── security.py    → JWT, bcrypt, get_current_user
            ├── email.py       → SMTP async
            └── exceptions.py → handlers HTTP globaux
```

---

## 6. Structure des fichiers

```
services-app/
│
├── .env                          # Variables d'environnement (secrets)
├── .env.example                  # Modèle .env sans secrets (à committer)
├── requirements.txt              # Dépendances production
├── requirements-dev.txt          # Dépendances développement (pytest, httpx…)
├── README.md
├── .gitignore
│
├── app/
│   ├── main.py                   # CORE — lifespan, CORS, routeurs, StaticFiles
│   │
│   ├── core/
│   │   ├── config.py             # CORE — Settings depuis .env (pydantic-settings)
│   │   ├── database.py           # CORE — Connexion MongoDB Atlas + init Beanie
│   │   ├── security.py           # CORE — JWT, bcrypt, get_current_user()
│   │   ├── email.py              # CORE — Envoi SMTP (vérif email, reset MDP)
│   │   └── exceptions.py         # CORE — HTTPException custom + handlers globaux
│   │
│   ├── models/                   # Documents Beanie = collections MongoDB
│   │   ├── __init__.py           # Exporte tous les Documents pour init Beanie
│   │   ├── user.py               # MODEL — collection "users"
│   │   ├── provider_profile.py   # MODEL — collection "provider_profiles"
│   │   ├── service_request.py    # MODEL — collection "service_requests"
│   │   ├── proposal.py           # MODEL — collection "proposals"
│   │   ├── message.py            # MODEL — collection "messages"
│   │   ├── review.py             # MODEL — collection "reviews"
│   │   ├── notification.py       # MODEL — collection "notifications"
│   │   └── category.py           # MODEL — collection "categories"
│   │
│   ├── schemas/                  # Pydantic v2 — validation entrées/sorties
│   │   ├── auth.py               # RegisterRequest, LoginRequest, TokenResponse…
│   │   ├── user.py               # UserOut, UserUpdate, ProviderOut…
│   │   ├── service_request.py    # ServiceRequestCreate, ServiceRequestOut…
│   │   ├── proposal.py           # ProposalCreate, ProposalOut…
│   │   ├── message.py            # MessageOut, WSMessagePayload, ConversationOut…
│   │   ├── review.py             # ReviewCreate, ReviewOut…
│   │   ├── notification.py       # NotificationOut…
│   │   ├── category.py           # CategoryCreate, CategoryOut…
│   │   └── common.py             # PaginatedResponse, MessageResponse, ErrorResponse
│   │
│   ├── routers/                  # Un router FastAPI par domaine métier
│   │   ├── auth.py               # ROUTER — /auth
│   │   ├── users.py              # ROUTER — /users
│   │   ├── requests.py           # ROUTER — /requests
│   │   ├── proposals.py          # ROUTER — /proposals
│   │   ├── messages.py           # ROUTER — /messages
│   │   ├── websocket.py          # ROUTER — /ws/chat/{room_id}
│   │   ├── reviews.py            # ROUTER — /reviews
│   │   ├── notifications.py      # ROUTER — /notifications
│   │   ├── categories.py         # ROUTER — /categories
│   │   ├── uploads.py            # ROUTER — /uploads
│   │   └── admin.py              # ROUTER — /admin
│   │
│   ├── services/                 # Logique métier pure (pas de Request/Response FastAPI)
│   │   ├── auth_service.py       # register, login, logout, verify_email, reset_password
│   │   ├── user_service.py       # get_user, update_user, delete_user, list_providers
│   │   ├── request_service.py    # create_request, get_nearby, update_status
│   │   ├── proposal_service.py   # submit_proposal, accept, decline
│   │   ├── message_service.py    # get_conversations, get_history, mark_read, save_message
│   │   ├── review_service.py     # create_review, get_provider_reviews, update_avg_rating
│   │   ├── notification_service.py # create_notification (flag PUSH_ENABLED)
│   │   ├── file_service.py       # save_upload, delete_file, get_file_url (local)
│   │   └── geo_service.py        # haversine_distance, filter_nearby (Python pur)
│   │
│   ├── websocket/
│   │   ├── manager.py            # WS — ConnectionManager : connect/disconnect/send/broadcast
│   │   └── handlers.py           # WS — traitement messages reçus, routing, sauvegarde BDD
│   │
│   └── utils/
│       ├── pagination.py         # Helpers pagination Beanie (skip/limit → PaginatedResponse)
│       ├── validators.py         # Validation téléphone, image (type/taille)
│       └── helpers.py            # Génération tokens email, room_id WS, slugify
│
├── uploads/                      # Stockage local servi par StaticFiles sur /static
│   ├── avatars/                  # Photos de profil
│   ├── portfolio/                # Photos de travaux prestataires
│   ├── requests/                 # Photos jointes aux demandes
│   ├── messages/                 # Images envoyées en chat
│   └── certificates/             # Justificatifs prestataires
│
└── tests/
    ├── conftest.py
    ├── test_auth.py
    ├── test_requests.py
    └── test_proposals.py
```

---

## 7. Modèles de données (MongoDB)

### Collection `users`
| Champ | Type | Description |
|-------|------|-------------|
| `_id` | ObjectId | Identifiant unique |
| `email` | str | Email unique |
| `phone` | str | Téléphone |
| `hashed_password` | str | Mot de passe bcrypt |
| `full_name` | str | Nom complet |
| `role` | enum | `client` \| `provider` \| `admin` |
| `avatar_url` | str | URL photo de profil |
| `is_verified` | bool | Email vérifié |
| `is_active` | bool | Compte actif (non banni) |
| `created_at` | datetime | Date de création |
| `refresh_token` | str | Token de refresh actuel |

### Collection `provider_profiles`
| Champ | Type | Description |
|-------|------|-------------|
| `user_id` | ObjectId | Référence → users |
| `bio` | str | Description du prestataire |
| `skills` | list[str] | Compétences / services proposés |
| `categories` | list[ObjectId] | Catégories d'intervention |
| `location` | object | `{lat, lng, city, address}` |
| `radius_km` | float | Rayon d'intervention (km) |
| `portfolio` | list[str] | URLs photos de travaux |
| `certificates` | list[str] | URLs justificatifs |
| `avg_rating` | float | Note moyenne (calculée) |
| `total_reviews` | int | Nombre d'avis |
| `is_verified_provider` | bool | Validé par admin |

### Collection `service_requests`
| Champ | Type | Description |
|-------|------|-------------|
| `client_id` | ObjectId | Référence → users |
| `category_id` | ObjectId | Référence → categories |
| `title` | str | Titre de la demande |
| `description` | str | Description détaillée |
| `photos` | list[str] | URLs photos jointes |
| `location` | object | `{lat, lng, address}` |
| `urgency` | enum | `low` \| `medium` \| `high` |
| `status` | enum | `open` \| `in_progress` \| `done` \| `cancelled` |
| `created_at` | datetime | |

### Collection `proposals`
| Champ | Type | Description |
|-------|------|-------------|
| `request_id` | ObjectId | Référence → service_requests |
| `provider_id` | ObjectId | Référence → users |
| `message` | str | Message de la proposition |
| `price_estimate` | float | Devis estimatif |
| `status` | enum | `pending` \| `accepted` \| `declined` |
| `created_at` | datetime | |

### Collection `messages`
| Champ | Type | Description |
|-------|------|-------------|
| `room_id` | str | Identifiant de la conversation |
| `sender_id` | ObjectId | Référence → users |
| `content` | str | Contenu texte |
| `media_url` | str | URL image/fichier joint |
| `is_read` | bool | Lu par le destinataire |
| `created_at` | datetime | |

### Collection `reviews`
| Champ | Type | Description |
|-------|------|-------------|
| `request_id` | ObjectId | Référence → service_requests |
| `reviewer_id` | ObjectId | Référence → users (client) |
| `provider_id` | ObjectId | Référence → users (prestataire) |
| `rating` | int | Note de 1 à 5 |
| `comment` | str | Commentaire |
| `created_at` | datetime | |

### Collection `notifications`
| Champ | Type | Description |
|-------|------|-------------|
| `user_id` | ObjectId | Destinataire |
| `type` | str | `new_proposal`, `accepted`, `message`, etc. |
| `title` | str | Titre |
| `body` | str | Corps du message |
| `is_read` | bool | Lu |
| `ref_id` | ObjectId | Référence à l'objet concerné |
| `created_at` | datetime | |

### Collection `categories`
| Champ | Type | Description |
|-------|------|-------------|
| `name` | str | Nom unique |
| `slug` | str | Slug URL |
| `icon` | str | Nom icône |
| `is_active` | bool | Visible dans l'app |

---

## 8. Endpoints API

### Auth — `/auth`
| Méthode | Endpoint | Auth | Description |
|---------|----------|------|-------------|
| POST | `/auth/register` | ✗ | Inscription |
| POST | `/auth/login` | ✗ | Connexion → access + refresh token |
| POST | `/auth/logout` | ✓ | Révocation du refresh token |
| POST | `/auth/refresh` | ✗ | Renouveler l'access token |
| GET | `/auth/verify-email` | ✗ | Vérifier l'email (lien token) |
| POST | `/auth/forgot-password` | ✗ | Envoyer lien reset MDP |
| POST | `/auth/reset-password` | ✗ | Réinitialiser le MDP |

### Utilisateurs — `/users`
| Méthode | Endpoint | Auth | Description |
|---------|----------|------|-------------|
| GET | `/users/me` | ✓ | Profil connecté |
| PUT | `/users/me` | ✓ | Modifier son profil |
| DELETE | `/users/me` | ✓ | Supprimer son compte |
| GET | `/users/{id}` | ✓ | Profil public d'un utilisateur |
| GET | `/users/providers` | ✓ | Liste des prestataires |
| GET | `/users/providers/{id}` | ✓ | Profil prestataire complet |
| PUT | `/users/providers/me` | ✓ | Modifier son profil prestataire |

### Demandes de service — `/requests`
| Méthode | Endpoint | Auth | Description |
|---------|----------|------|-------------|
| POST | `/requests` | ✓ | Créer une demande |
| GET | `/requests` | ✓ | Lister les demandes (filtre catégorie/statut) |
| GET | `/requests/nearby` | ✓ | Demandes à proximité (Haversine) |
| GET | `/requests/{id}` | ✓ | Détail d'une demande |
| PUT | `/requests/{id}` | ✓ | Modifier (auteur seulement) |
| DELETE | `/requests/{id}` | ✓ | Supprimer (auteur seulement) |
| PATCH | `/requests/{id}/status` | ✓ | Changer le statut |

### Propositions — `/proposals`
| Méthode | Endpoint | Auth | Description |
|---------|----------|------|-------------|
| POST | `/proposals` | ✓ | Soumettre une proposition |
| GET | `/proposals/request/{req_id}` | ✓ | Propositions d'une demande |
| GET | `/proposals/mine` | ✓ | Mes propositions (prestataire) |
| POST | `/proposals/{id}/accept` | ✓ | Accepter une proposition |
| POST | `/proposals/{id}/decline` | ✓ | Refuser une proposition |
| DELETE | `/proposals/{id}` | ✓ | Supprimer ma proposition |

### Messages — `/messages`
| Méthode | Endpoint | Auth | Description |
|---------|----------|------|-------------|
| GET | `/messages/conversations` | ✓ | Liste des conversations |
| GET | `/messages/{room_id}/history` | ✓ | Historique d'une conversation |
| POST | `/messages/{room_id}` | ✓ | Envoyer un message (REST) |
| PATCH | `/messages/{room_id}/read` | ✓ | Marquer comme lu |

### WebSocket — `/ws`
| Protocole | Endpoint | Auth | Description |
|-----------|----------|------|-------------|
| WS | `/ws/chat/{room_id}?token=...` | ✓ JWT | Canal temps réel authentifié |

### Avis — `/reviews`
| Méthode | Endpoint | Auth | Description |
|---------|----------|------|-------------|
| POST | `/reviews` | ✓ | Créer un avis |
| GET | `/reviews/provider/{id}` | ✓ | Avis d'un prestataire |
| DELETE | `/reviews/{id}` | ✓ | Supprimer son avis |

### Notifications — `/notifications`
| Méthode | Endpoint | Auth | Description |
|---------|----------|------|-------------|
| GET | `/notifications` | ✓ | Liste des notifications |
| PATCH | `/notifications/{id}/read` | ✓ | Marquer comme lue |
| PATCH | `/notifications/read-all` | ✓ | Tout marquer comme lu |
| GET | `/notifications/unread-count` | ✓ | Compteur non lues |

### Catégories — `/categories`
| Méthode | Endpoint | Auth | Description |
|---------|----------|------|-------------|
| GET | `/categories` | ✗ | Liste des catégories actives |
| GET | `/categories/{id}` | ✗ | Détail d'une catégorie |

### Uploads — `/uploads`
| Méthode | Endpoint | Auth | Description |
|---------|----------|------|-------------|
| POST | `/uploads/image` | ✓ | Upload image (avatar, portfolio…) |
| GET | `/static/{path}` | ✗ | Servir un fichier statique |
| DELETE | `/uploads/{id}` | ✓ | Supprimer un fichier |

### Admin — `/admin`
| Méthode | Endpoint | Auth | Description |
|---------|----------|------|-------------|
| GET | `/admin/users` | ✓ ADMIN | Liste tous les utilisateurs |
| POST | `/admin/users/{id}/ban` | ✓ ADMIN | Bannir un utilisateur |
| POST | `/admin/providers/{id}/verify` | ✓ ADMIN | Valider un prestataire |
| GET | `/admin/stats` | ✓ ADMIN | Statistiques globales |
| POST | `/admin/categories` | ✓ ADMIN | Créer une catégorie |

---

## 9. Authentification & Sécurité

### Flux complet
```
1. POST /auth/register   → hash bcrypt du MDP → sauvegarde User → envoi email vérification
2. GET  /auth/verify-email?token=xxx → activation du compte
3. POST /auth/login      → vérif MDP → génération access_token (15 min) + refresh_token (7j)
4. Requêtes protégées    → Header: Authorization: Bearer <access_token>
5. POST /auth/refresh    → échange refresh_token → nouvel access_token
6. POST /auth/logout     → révocation refresh_token en BDD
```

### Règles JWT
- **Access token** : durée 15 minutes, HS256
- **Refresh token** : durée 7 jours, stocké en BDD (révocable)
- **Rotation** : nouveau refresh token à chaque `/auth/refresh`

### Dépendances FastAPI
```python
get_current_user()    # tout utilisateur authentifié
get_admin_user()      # admin uniquement (role == "admin")
get_provider_user()   # prestataire uniquement (role == "provider")
```

---

## 10. WebSocket — Messagerie temps réel

```
Client A ──── WS /ws/chat/{room_id}?token=JWT ────┐
                                                   ▼
                                         ConnectionManager (mémoire)
                                           connect() / disconnect()
                                           broadcast(room_id, msg)
Client B ──── WS /ws/chat/{room_id}?token=JWT ────┘
                                                   │
                                                   ▼
                                         handlers.py → save_message() → MongoDB
```

- **`room_id`** : généré depuis les deux IDs utilisateurs (`helper.generate_room_id(uid_a, uid_b)`)
- **Authentification** : token JWT passé en query param (pas de cookie ni header WS)
- **Format message** : JSON `{ type, content, media_url, sender_id, room_id, timestamp }`
- **Persistance** : chaque message WS est sauvegardé en BDD via `message_service`

---

## 11. Stockage local des fichiers

```
uploads/
├── avatars/        → POST /uploads/image?type=avatar
├── portfolio/      → POST /uploads/image?type=portfolio
├── requests/       → POST /uploads/image?type=request
├── messages/       → POST /uploads/image?type=message
└── certificates/   → POST /uploads/image?type=certificate
```

- Servi via FastAPI `StaticFiles` sur `/static`
- URL publique : `http://localhost:8000/static/avatars/nom_fichier.jpg`
- Taille max : `MAX_FILE_SIZE_MB` (défaut 10 Mo)
- Types acceptés : `image/jpeg`, `image/png`, `image/webp`
- **En production** : remplacer par Firebase Storage / AWS S3 (flag `CLOUD_STORAGE_ENABLED=true`)

---

## 12. Variables d'environnement (.env)

```env
# ── Application ─────────────────────────────────────────
APP_NAME="Services à la Demande"
APP_ENV=development
DEBUG=true
SECRET_KEY="change-me-to-a-long-random-string-minimum-32-chars"
CORS_ORIGINS="http://localhost:3000,http://localhost:8081"

# ── MongoDB Atlas ────────────────────────────────────────
MONGODB_URL=mongodb+srv://user:password@cluster0.xxxxx.mongodb.net/?appName=Cluster0
DB_NAME=services_app

# ── JWT ──────────────────────────────────────────────────
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=15
REFRESH_TOKEN_EXPIRE_DAYS=7

# ── Stockage local ───────────────────────────────────────
UPLOAD_DIR=./uploads
MAX_FILE_SIZE_MB=10
STATIC_URL="http://localhost:8000/static"

# ── Email SMTP (Gmail gratuit) ───────────────────────────
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER="ton.email@gmail.com"
SMTP_PASSWORD="ton-app-password-gmail"
EMAIL_FROM="Services App <ton.email@gmail.com>"

# ── Feature flags — désactivés en version Starter ────────
PUSH_NOTIFICATIONS_ENABLED=false
SMS_ENABLED=false
GOOGLE_OAUTH_ENABLED=false
GOOGLE_MAPS_ENABLED=false
OCR_ENABLED=false
CLOUD_STORAGE_ENABLED=false
REDIS_ENABLED=false

# ── Clés futures (laisser vides) ─────────────────────────
TWILIO_SID=
TWILIO_TOKEN=
FIREBASE_CREDENTIALS=
GOOGLE_MAPS_KEY=
REDIS_URL=
```

---

## 13. Dépendances Python

### Production (`requirements.txt`)
```
fastapi>=0.111.0
uvicorn[standard]>=0.29.0
motor>=3.4.0               # driver MongoDB async
beanie>=1.26.0             # ODM MongoDB (Pydantic v2)
pydantic[email]>=2.7.0
pydantic-settings>=2.2.0
python-jose[cryptography]>=3.3.0  # JWT
passlib[bcrypt]>=1.7.4     # hachage bcrypt
aiosmtplib>=3.0.0          # SMTP async
python-multipart>=0.0.9    # uploads fichiers
aiofiles>=23.2.1           # I/O fichiers async
python-dotenv>=1.0.1
```

### Développement (`requirements-dev.txt`)
```
pytest>=8.2.0
pytest-asyncio>=0.23.0
httpx>=0.27.0              # client async pour les tests
```

---

## 14. Installation & Lancement

### Prérequis
- Python 3.11+
- Un compte [MongoDB Atlas](https://www.mongodb.com/atlas) (cluster gratuit M0)
- Un compte Gmail avec un [App Password](https://support.google.com/accounts/answer/185833)

### Étapes

```bash
# 1. Cloner le projet
git clone <repo>
cd services-app

# 2. Créer et activer l'environnement virtuel
python -m venv venv
venv\Scripts\activate        # Windows
# source venv/bin/activate   # Linux/Mac

# 3. Installer les dépendances
pip install -r requirements.txt
pip install -r requirements-dev.txt  # pour les tests

# 4. Configurer l'environnement
cp .env.example .env
# Éditer .env : renseigner MONGODB_URL, SECRET_KEY, SMTP_USER, SMTP_PASSWORD

# 5. Créer les dossiers uploads
mkdir -p uploads/avatars uploads/portfolio uploads/requests uploads/messages uploads/certificates

# 6. Lancer l'API
uvicorn app.main:app --reload --port 8000
```

### URLs
- **API** : http://localhost:8000
- **Docs Swagger** : http://localhost:8000/docs
- **Docs ReDoc** : http://localhost:8000/redoc
- **Fichiers statiques** : http://localhost:8000/static/

### Lancer les tests
```bash
pytest tests/ -v
```

---

## 15. Feature Flags — Services désactivés (Starter)

Ces fonctionnalités sont **architecturées mais désactivées** pour rester 100 % gratuit.  
Elles s'activent en changeant la valeur dans `.env` et en branchant les clés correspondantes.

| Flag | Valeur Starter | Service remplacé par | Activation future |
|------|---------------|----------------------|-------------------|
| `PUSH_NOTIFICATIONS_ENABLED` | `false` | Notifications in-app (BDD) | Firebase FCM |
| `SMS_ENABLED` | `false` | Email SMTP | Twilio |
| `GOOGLE_OAUTH_ENABLED` | `false` | Email/MDP classique | Google OAuth2 |
| `GOOGLE_MAPS_ENABLED` | `false` | Haversine Python pur | Google Maps API |
| `OCR_ENABLED` | `false` | Upload manuel | Tesseract / Google Vision |
| `CLOUD_STORAGE_ENABLED` | `false` | Stockage local `/uploads` | Firebase Storage / AWS S3 |
| `REDIS_ENABLED` | `false` | WS en mémoire (1 instance) | Redis Pub/Sub (multi-instance) |

---

## 16. Planning de développement

| Phase | Contenu | Priorité |
|-------|---------|----------|
| **Phase 1** | Setup projet, config DB, core (config, database, security, email, exceptions) | 🔴 Critique |
| **Phase 2** | Models Beanie + Schemas Pydantic v2 | 🔴 Critique |
| **Phase 3** | Auth complet (register, login, refresh, verify-email, reset-password) | 🔴 Critique |
| **Phase 4** | CRUD Users & ProviderProfile | 🟠 Haute |
| **Phase 5** | ServiceRequests + Proposals (cœur métier) | 🟠 Haute |
| **Phase 6** | Messagerie REST + WebSocket temps réel | 🟠 Haute |
| **Phase 7** | Reviews + Notifications in-app | 🟡 Moyenne |
| **Phase 8** | Uploads fichiers + StaticFiles | 🟡 Moyenne |
| **Phase 9** | Catégories + Admin back-office | 🟡 Moyenne |
| **Phase 10** | Tests pytest, documentation, déploiement | 🟢 Finale |

---

## Modèle économique

- **Commission sur transactions** : un pourcentage est prélevé sur chaque transaction réalisée via la plateforme
- **Zone cible initiale** : Ouagadougou et grandes villes du Burkina Faso (extensible)

---

## Auteur

**KIEMTORE Bienvenue** — Projet de fin de Licence  
Version 1.0 — Février 2026
