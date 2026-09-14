from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict

from app.models.enums import (
    ConflictResolutionKind,
    SyncEntityType,
    SyncOperationType,
    SyncQueueStatus,
)


class SyncConflictRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    entity_type: SyncEntityType
    entity_id: str
    resolution: ConflictResolutionKind
    winner_operation_id: uuid.UUID
    loser_operation_id: uuid.UUID
    reason: str
    detected_at: datetime
    resolved_at: datetime | None = None


class SyncOperationRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    operation_id: uuid.UUID
    device_id: str
    actor_id: str
    entity_type: SyncEntityType
    entity_id: str
    operation_type: SyncOperationType
    queue_status: SyncQueueStatus
    version: int
    logical_timestamp: int
    created_at: datetime
    failure_reason: str | None = None


class SyncOperationPage(BaseModel):
    items: list[SyncOperationRead]
    total: int
