"""Authentication use-cases.

Holds the rules; knows nothing about HTTP. Routes translate its output into
responses, repositories translate its intent into SQL.
"""

from __future__ import annotations

import uuid

from sqlalchemy.orm import Session

from app.core.errors import AuthenticationError, ConflictError
from app.core.security import (
    TokenType,
    create_token,
    decode_token,
    hash_password,
    token_expiry_seconds,
    verify_password,
)
from app.models.user import User
from app.repositories.user_repository import UserRepository
from app.schemas.auth import TokenPair
from app.schemas.user import UserCreate


class AuthService:
    def __init__(self, session: Session) -> None:
        self.users = UserRepository(session)

    def authenticate(self, email: str, password: str) -> User:
        user = self.users.get_by_email(email)

        # Hash a throwaway value when the account is missing so a wrong email
        # and a wrong password take the same time to reject.
        if user is None:
            verify_password(password, _DUMMY_HASH)
            raise AuthenticationError("Invalid email or password")

        if not verify_password(password, user.hashed_password):
            raise AuthenticationError("Invalid email or password")

        if not user.is_active:
            raise AuthenticationError("This account has been deactivated")

        return user

    def issue_tokens(self, user: User) -> TokenPair:
        subject = str(user.id)
        return TokenPair(
            access_token=create_token(subject, user.role.value, TokenType.ACCESS),
            refresh_token=create_token(subject, user.role.value, TokenType.REFRESH),
            expires_in=token_expiry_seconds(TokenType.ACCESS),
        )

    def refresh(self, refresh_token: str) -> tuple[User, TokenPair]:
        payload = decode_token(refresh_token, expected_type=TokenType.REFRESH)
        user = self._user_from_subject(payload.get("sub"))
        return user, self.issue_tokens(user)

    def resolve_access_token(self, access_token: str) -> User:
        payload = decode_token(access_token, expected_type=TokenType.ACCESS)
        return self._user_from_subject(payload.get("sub"))

    def register(self, payload: UserCreate) -> User:
        if self.users.email_exists(payload.email):
            raise ConflictError("An account with this email already exists")
        user = User(
            email=payload.email.strip().lower(),
            full_name=payload.full_name,
            role=payload.role,
            hashed_password=hash_password(payload.password),
        )
        return self.users.add(user)

    def _user_from_subject(self, subject: str | None) -> User:
        if not subject:
            raise AuthenticationError("Token is missing a subject")
        try:
            user_id = uuid.UUID(subject)
        except ValueError as exc:
            raise AuthenticationError("Token subject is malformed") from exc

        user = self.users.get(user_id)
        if user is None or not user.is_active:
            raise AuthenticationError("Account is no longer valid")
        return user


# Pre-computed bcrypt digest of a random string, used only for timing parity.
_DUMMY_HASH = hash_password(uuid.uuid4().hex)
