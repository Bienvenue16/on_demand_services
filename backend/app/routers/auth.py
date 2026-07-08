from fastapi import APIRouter, Depends
from app.schemas.auth import (
    RegisterRequest, LoginRequest, TokenResponse,
    RefreshRequest, ForgotPasswordRequest, ResetPasswordRequest,
)
from app.schemas.common import MessageResponse
from app.services import auth_service
from app.core.security import get_current_user

router = APIRouter()


@router.post("/register", response_model=MessageResponse, status_code=201)
async def register(body: RegisterRequest):
    return await auth_service.register(body)


@router.post("/login", response_model=TokenResponse)
async def login(body: LoginRequest):
    return await auth_service.login(body)


@router.post("/logout", response_model=MessageResponse)
async def logout(current_user=Depends(get_current_user)):
    return await auth_service.logout(current_user)


@router.post("/refresh", response_model=TokenResponse)
async def refresh(body: RefreshRequest):
    return await auth_service.refresh_token(body.refresh_token)


@router.get("/verify-email", response_model=MessageResponse)
async def verify_email(token: str):
    return await auth_service.verify_email(token)


@router.post("/forgot-password", response_model=MessageResponse)
async def forgot_password(body: ForgotPasswordRequest):
    return await auth_service.forgot_password(body.email)


@router.post("/reset-password", response_model=MessageResponse)
async def reset_password(body: ResetPasswordRequest):
    return await auth_service.reset_password(body.token, body.new_password)
