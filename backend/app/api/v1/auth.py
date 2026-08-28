"""Authentication endpoints."""

from __future__ import annotations

from fastapi import APIRouter, status

from app.api.deps import AuthServiceDep, CurrentUser
from app.schemas.auth import LoginRequest, LoginResponse, RefreshRequest, TokenPair
from app.schemas.user import UserRead

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/login", response_model=LoginResponse, summary="Exchange credentials for tokens")
def login(payload: LoginRequest, auth_service: AuthServiceDep) -> LoginResponse:
    user = auth_service.authenticate(payload.email, payload.password)
    tokens = auth_service.issue_tokens(user)
    return LoginResponse(**tokens.model_dump(), user=UserRead.model_validate(user))


@router.post("/refresh", response_model=TokenPair, summary="Rotate an access token")
def refresh(payload: RefreshRequest, auth_service: AuthServiceDep) -> TokenPair:
    _, tokens = auth_service.refresh(payload.refresh_token)
    return tokens


@router.get(
    "/me",
    response_model=UserRead,
    status_code=status.HTTP_200_OK,
    summary="Profile of the authenticated responder",
)
def me(current_user: CurrentUser) -> UserRead:
    return UserRead.model_validate(current_user)
