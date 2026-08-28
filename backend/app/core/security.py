"""Password hashing and JWT issuing/verification primitives."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta
from enum import StrEnum
from typing import Any

import bcrypt
import jwt

from app.core.config import settings
from app.core.errors import AuthenticationError

# bcrypt silently ignores anything past 72 bytes, so we reject longer inputs
# rather than accept a password whose tail is never checked.
MAX_PASSWORD_BYTES = 72


class TokenType(StrEnum):
    ACCESS = "access"
    REFRESH = "refresh"


def hash_password(plain_password: str) -> str:
    _guard_password_length(plain_password)
    return bcrypt.hashpw(plain_password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    try:
        _guard_password_length(plain_password)
        return bcrypt.checkpw(plain_password.encode("utf-8"), hashed_password.encode("utf-8"))
    except (ValueError, TypeError):
        return False


def _guard_password_length(plain_password: str) -> None:
    if len(plain_password.encode("utf-8")) > MAX_PASSWORD_BYTES:
        raise ValueError(f"Password must not exceed {MAX_PASSWORD_BYTES} bytes")


def create_token(
    subject: str,
    role: str,
    token_type: TokenType = TokenType.ACCESS,
    expires_delta: timedelta | None = None,
) -> str:
    now = datetime.now(UTC)
    if expires_delta is None:
        minutes = (
            settings.access_token_expire_minutes
            if token_type is TokenType.ACCESS
            else settings.refresh_token_expire_minutes
        )
        expires_delta = timedelta(minutes=minutes)

    payload: dict[str, Any] = {
        "sub": subject,
        "role": role,
        "type": token_type.value,
        "iat": int(now.timestamp()),
        "exp": int((now + expires_delta).timestamp()),
        "jti": str(uuid.uuid4()),
    }
    return jwt.encode(payload, settings.jwt_key, algorithm=settings.jwt_algorithm)


def decode_token(token: str, expected_type: TokenType | None = None) -> dict[str, Any]:
    try:
        payload: dict[str, Any] = jwt.decode(
            token, settings.jwt_key, algorithms=[settings.jwt_algorithm]
        )
    except jwt.ExpiredSignatureError as exc:
        raise AuthenticationError("Token has expired") from exc
    except jwt.PyJWTError as exc:
        raise AuthenticationError("Invalid authentication token") from exc

    if expected_type is not None and payload.get("type") != expected_type.value:
        article = "an" if expected_type.value[0] in "aeiou" else "a"
        raise AuthenticationError(f"Expected {article} {expected_type.value} token")
    return payload


def token_expiry_seconds(token_type: TokenType = TokenType.ACCESS) -> int:
    minutes = (
        settings.access_token_expire_minutes
        if token_type is TokenType.ACCESS
        else settings.refresh_token_expire_minutes
    )
    return minutes * 60
