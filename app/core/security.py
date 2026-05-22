from datetime import datetime, timedelta, timezone
from jose import JWTError, jwt
import bcrypt
from fastapi import Depends, HTTPException, status, Request
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
    """Ajoute un token à la blacklist (utilisé lors du logout forcé / ban)."""
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
    entry = await BlacklistedToken.find_one(BlacklistedToken.token == token)
    return entry is not None


async def get_current_user(token: str = Depends(oauth2_scheme)):
    from app.models.user import User
    credentials_exc = HTTPException(status.HTTP_401_UNAUTHORIZED, detail="Token invalide ou expiré")
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
        user_id: str = payload.get("sub")
        if not user_id:
            raise credentials_exc
    except JWTError:
        raise credentials_exc
    if await is_token_blacklisted(token):
        raise credentials_exc
    user = await User.get(user_id)
    if not user or not user.is_active:
        raise credentials_exc
    if user.is_banned:
        raise HTTPException(status.HTTP_403_FORBIDDEN, detail=f"Compte banni : {user.banned_reason or 'violation des CGU'}")
    return user


async def get_current_user_ws(token: str):
    """Variante pour WebSocket (token passé en query param)."""
    from app.models.user import User
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
        user_id: str = payload.get("sub")
        if not user_id:
            return None
    except JWTError:
        return None
    if await is_token_blacklisted(token):
        return None
    user = await User.get(user_id)
    if not user or not user.is_active or user.is_banned:
        return None
    return user


async def get_admin_user(current_user=Depends(get_current_user)):
    from app.models.user import UserRole
    if current_user.role != UserRole.admin:
        raise HTTPException(status.HTTP_403_FORBIDDEN, detail="Accès réservé aux administrateurs")
    return current_user


async def get_provider_user(current_user=Depends(get_current_user)):
    from app.models.user import UserRole
    if current_user.role not in (UserRole.provider, UserRole.admin):
        raise HTTPException(status.HTTP_403_FORBIDDEN, detail="Accès réservé aux prestataires")
    return current_user



async def get_current_user(token: str = Depends(oauth2_scheme)):
    from app.models.user import User
    credentials_exc = HTTPException(status.HTTP_401_UNAUTHORIZED, detail="Token invalide ou expiré")
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


async def get_current_user_ws(token: str):
    """Variante pour WebSocket (token passé en query param)."""
    from app.models.user import User
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
        user_id: str = payload.get("sub")
        if not user_id:
            return None
    except JWTError:
        return None
    user = await User.get(user_id)
    if not user or not user.is_active:
        return None
    return user


async def get_admin_user(current_user=Depends(get_current_user)):
    if current_user.role != "admin":
        raise HTTPException(status.HTTP_403_FORBIDDEN, detail="Accès admin requis")
    return current_user


async def get_provider_user(current_user=Depends(get_current_user)):
    if current_user.role != "provider":
        raise HTTPException(status.HTTP_403_FORBIDDEN, detail="Accès prestataire requis")
    return current_user
