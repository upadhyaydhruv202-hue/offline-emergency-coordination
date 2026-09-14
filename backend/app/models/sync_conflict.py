from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, String, Text, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin, UuidPrimaryKeyMixin
from app.models.enums import ConflictResolutionKind, SyncEntityType
from app.models.sync_operation import _enum


class SyncConflict(UuidPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "sync_conflicts"

    entity_type: Mapped[SyncEntityType] = mapped_column(
        _enum(SyncEntityType, "sync_entity_type"), nullable=False
    )
    entity_id: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    operation_a_id: Mapped[uuid.UUID] = mapped_column(Uuid, nullable=False)
    operation_b_id: Mapped[uuid.UUID] = mapped_column(Uuid, nullable=False)
    detected_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    resolution: Mapped[ConflictResolutionKind] = mapped_column(
        _enum(ConflictResolutionKind, "conflict_resolution_kind"), nullable=False
    )
    winner_operation_id: Mapped[uuid.UUID] = mapped_column(Uuid, nullable=False)
    loser_operation_id: Mapped[uuid.UUID] = mapped_column(Uuid, nullable=False)
    reason: Mapped[str] = mapped_column(Text, nullable=False)
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
