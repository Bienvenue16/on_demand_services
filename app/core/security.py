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
