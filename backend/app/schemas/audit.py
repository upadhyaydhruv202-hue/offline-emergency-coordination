from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.models.enums import AuditSeverity


class AuditEventRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    category: str
    summary: str
    severity: AuditSeverity
    entity_type: str | None
    entity_id: str | None
    actor_id: str | None
    occurred_at: datetime
    created_at: datetime


class AuditEventCreate(BaseModel):
    category: str = Field(min_length=1, max_length=32)
    summary: str = Field(min_length=1, max_length=2000)
    severity: AuditSeverity = AuditSeverity.INFO
    entity_type: str | None = Field(default=None, max_length=32)
    entity_id: str | None = Field(default=None, max_length=64)
    actor_id: str | None = Field(default=None, max_length=128)
    occurred_at: datetime


class AuditEventPage(BaseModel):
    items: list[AuditEventRead]
    total: int
