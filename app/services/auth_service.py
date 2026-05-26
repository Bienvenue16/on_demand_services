import logging
from datetime import datetime, timezone
from fastapi import HTTPException, status
from app.models.user import User
from app.schemas.auth import RegisterRequest, LoginRequest, TokenResponse
from app.schemas.common import MessageResponse
from app.core.security import hash_password, verify_password, create_access_token, create_refresh_token
from app.core.email import send_verification_email, send_reset_password_email
from app.utils.helpers import generate_token

logger = logging.getLogger(__name__)


async def register(body: RegisterRequest) -> MessageResponse:
    existing = await User.find_one(User.email == body.email)
    if existing:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="Email déjà utilisé")
    from app.core.config import settings
    token = generate_token()
    # En mode DEBUG, on auto-vérifie l'utilisateur (SMTP non configuré)
    auto_verified = settings.DEBUG
    user = User(
        email=body.email,
        hashed_password=hash_password(body.password),
        full_name=body.full_name,
        phone=body.phone,
        role=body.role,
        verification_token=None if auto_verified else token,
        is_verified=auto_verified,
    )
    await user.insert()

    # Créer un profil prestataire vide si role=provider
    if user.role.value == "provider":
        from app.models.provider_profile import ProviderProfile
        await ProviderProfile(user_id=str(user.id)).insert()

    if not auto_verified:
        try:
            await send_verification_email(body.email, token)
        except Exception as exc:
            logger.warning("Envoi email échoué (SMTP non configuré ?): %s", exc)
    return MessageResponse(message="Inscription réussie." + (" Compte auto-vérifié (mode debug)." if auto_verified else " Vérifiez votre email."))


async def login(body: LoginRequest) -> TokenResponse:
    from app.core.config import settings
    user = await User.find_one(User.email == body.email)
    if not user or not verify_password(body.password, user.hashed_password):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail="Identifiants invalides")
    if not settings.DEBUG and not user.is_verified:
        raise HTTPException(status.HTTP_403_FORBIDDEN, detail="Email non vérifié. Consultez votre boîte mail.")
    if not settings.DEBUG and not user.is_active:
        raise HTTPException(status.HTTP_403_FORBIDDEN, detail="Compte désactivé")
    access_token = create_access_token(str(user.id))
    refresh_token = create_refresh_token(str(user.id))
    user.refresh_token = refresh_token
    await user.save()
    return TokenResponse(access_token=access_token, refresh_token=refresh_token)


async def logout(user: User) -> MessageResponse:
    user.refresh_token = None
    await user.save()
    return MessageResponse(message="Déconnexion réussie")


# Fenêtre de tolérance pour les refresh concurrents (en secondes)
_REFRESH_GRACE_SECONDS = 30


async def refresh_token(token: str) -> TokenResponse:
    from jose import JWTError, jwt
    from app.core.config import settings
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
        user_id: str = payload.get("sub")
    except JWTError:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail="Token invalide")

    user = await User.get(user_id)
    if not user:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail="Token révoqué ou invalide")

    now = datetime.now(timezone.utc)

    # Cas 1 : token == refresh actuel → rotation normale
    if user.refresh_token == token:
        new_access = create_access_token(str(user.id))
        new_refresh = create_refresh_token(str(user.id))
        user.prev_refresh_token = token
        user.refresh_token_rotated_at = now
        user.refresh_token = new_refresh
        await user.save()
        return TokenResponse(access_token=new_access, refresh_token=new_refresh)

    # Cas 2 : token == ancien refresh ET dans la fenêtre de tolérance
    # → requête concurrente : on retourne les tokens déjà émis
    if (
        user.prev_refresh_token == token
        and user.refresh_token_rotated_at is not None
        and (now - user.refresh_token_rotated_at).total_seconds() <= _REFRESH_GRACE_SECONDS
    ):
        # Réémet un nouvel access token (l'ancien a peut-être déjà expiré)
        new_access = create_access_token(str(user.id))
        return TokenResponse(access_token=new_access, refresh_token=user.refresh_token)

    raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail="Token révoqué ou invalide")


async def verify_email(token: str) -> MessageResponse:
    user = await User.find_one(User.verification_token == token)
    if not user:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="Token de vérification invalide")
    user.is_verified = True
    user.verification_token = None
    await user.save()
    return MessageResponse(message="Email vérifié avec succès. Vous pouvez vous connecter.")


async def forgot_password(email: str) -> MessageResponse:
    user = await User.find_one(User.email == email)
    if user:
        token = generate_token()
        user.reset_token = token
        await user.save()
        await send_reset_password_email(email, token)
    return MessageResponse(message="Si cet email existe, un lien de réinitialisation a été envoyé.")


async def reset_password(token: str, new_password: str) -> MessageResponse:
    user = await User.find_one(User.reset_token == token)
    if not user:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="Token invalide ou expiré")
    user.hashed_password = hash_password(new_password)
    user.reset_token = None
    await user.save()
    return MessageResponse(message="Mot de passe réinitialisé avec succès")
