from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.models.enums import ResponderStatus
from app.schemas.user import UserRead


class PresenceUpdate(BaseModel):
    status: ResponderStatus | None = None
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    device_id: str | None = Field(default=None, max_length=64)
    assigned_incident_id: uuid.UUID | None = None
    assigned_task: str | None = Field(default=None, max_length=160)


class PresenceRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    user_id: uuid.UUID
    status: ResponderStatus
    latitude: float | None
    longitude: float | None
    last_seen_at: datetime
    device_id: str | None
    assigned_incident_id: uuid.UUID | None
    assigned_task: str | None
    updated_at: datetime


class ResponderOperationalRead(UserRead):
    presence: PresenceRead | None = None
