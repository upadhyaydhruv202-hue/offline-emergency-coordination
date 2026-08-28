"""User-facing representations of :class:`~app.models.user.User`."""

from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr, Field

from app.core.security import MAX_PASSWORD_BYTES
from app.models.enums import UserRole


class UserBase(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    email: EmailStr
    full_name: str = Field(min_length=1, max_length=160)
    role: UserRole


class UserCreate(UserBase):
    password: str = Field(min_length=8, max_length=MAX_PASSWORD_BYTES)


class UserRead(UserBase):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    is_active: bool
    created_at: datetime
