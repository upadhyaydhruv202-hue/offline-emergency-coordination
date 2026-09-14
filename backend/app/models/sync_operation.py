"""Outbound / inbound sync operations uploaded by field devices.

The command centre is a peer, not the source of truth during a partition.
"""

from __future__ import annotations

import uuid

from sqlalchemy import Enum, Index, Integer, String, Text, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin, UuidPrimaryKeyMixin
from app.models.enums import SyncEntityType, SyncOperationType, SyncQueueStatus


def _enum(enum_cls: type, name: str) -> Enum:
    # native_enum=False so SQLite tests and the two tables that share
    # ``sync_entity_type`` do not fight over a PostgreSQL type object.
    return Enum(
        enum_cls,
        name=name,
        values_callable=lambda cls: [member.value for member in cls],
        native_enum=False,
        length=32,
    )


class SyncOperation(UuidPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "sync_operations"

    operation_id: Mapped[uuid.UUID] = mapped_column(Uuid, unique=True, nullable=False, index=True)
    device_id: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    actor_id: Mapped[str] = mapped_column(String(128), nullable=False)
    entity_type: Mapped[SyncEntityType] = mapped_column(
        _enum(SyncEntityType, "sync_entity_type"), nullable=False
    )
    entity_id: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    operation_type: Mapped[SyncOperationType] = mapped_column(
        _enum(SyncOperationType, "sync_operation_type"), nullable=False
    )
    payload_json: Mapped[str] = mapped_column(Text, nullable=False)
    queue_status: Mapped[SyncQueueStatus] = mapped_column(
        _enum(SyncQueueStatus, "sync_queue_status"),
        nullable=False,
        default=SyncQueueStatus.PENDING,
    )
    version: Mapped[int] = mapped_column(Integer, nullable=False)
    logical_timestamp: Mapped[int] = mapped_column(Integer, nullable=False)
    parent_version: Mapped[int | None] = mapped_column(Integer, nullable=True)
    failure_reason: Mapped[str | None] = mapped_column(Text, nullable=True)

    __table_args__ = (Index("ix_sync_operations_entity", "entity_type", "entity_id"),)
