"""Shared FastAPI dependencies."""

from __future__ import annotations

from collections.abc import Callable, Iterable
from typing import Annotated

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.errors import AuthenticationError, AuthorizationError
from app.db.session import get_session
from app.models.enums import UserRole
from app.models.user import User
from app.services.auth_service import AuthService

bearer_scheme = HTTPBearer(auto_error=False, description="JWT access token")

DbSession = Annotated[Session, Depends(get_session)]


def get_auth_service(session: DbSession) -> AuthService:
    return AuthService(session)


AuthServiceDep = Annotated[AuthService, Depends(get_auth_service)]


def get_current_user(
    auth_service: AuthServiceDep,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)],
) -> User:
    if credentials is None or not credentials.credentials:
        raise AuthenticationError("Missing bearer token")
    return auth_service.resolve_access_token(credentials.credentials)


CurrentUser = Annotated[User, Depends(get_current_user)]


def require_roles(*allowed: UserRole) -> Callable[[User], User]:
    """Build a dependency that admits only the listed roles.

    This is the single extension point for authorization. Later slices refine
    *what* a role may do; routes keep declaring *which* roles they accept here.
    """
    allowed_set: frozenset[UserRole] = frozenset(allowed)

    def _dependency(current_user: CurrentUser) -> User:
        if current_user.role not in allowed_set:
            raise AuthorizationError(
                "Your role is not permitted to perform this action",
                details={"required_roles": _role_values(allowed_set)},
            )
        return current_user

    return _dependency


def _role_values(roles: Iterable[UserRole]) -> list[str]:
    return sorted(role.value for role in roles)
