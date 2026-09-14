"""Slice 4: sync queue, recorded conflicts, hazard type for R-12 demo.

Additive only. ``PARTIALLY_ACCESSIBLE`` is appended to ``hazard_type`` on
PostgreSQL; SQLite stores the column as text so the ALTER is skipped.

Revision ID: 0004_sync
Revises: 0003_field_operations
Create Date: 2026-09-14
"""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0004_sync"
down_revision: str | None = "0003_field_operations"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

SYNC_ENTITY_TYPES = (
    "INCIDENT",
    "VICTIM",
    "HAZARD",
    "TASK",
    "SOS",
    "RESPONDER_STATUS",
)
SYNC_OPERATION_TYPES = ("CREATE", "UPDATE", "DELETE")
SYNC_QUEUE_STATUSES = ("PENDING", "IN_FLIGHT", "ACKNOWLEDGED", "FAILED", "CONFLICT")
CONFLICT_RESOLUTIONS = (
    "LAST_WRITER_WINS",
    "DEVICE_TIE_BREAK",
    "OPERATION_TIE_BREAK",
    "MERGED",
    "MANUAL_REVIEW",
)


def _enum(values: tuple[str, ...], name: str) -> sa.types.TypeEngine[str]:
    bind = op.get_bind()
    if bind.dialect.name != "postgresql":
        return sa.Enum(*values, name=name)
    enum_type = postgresql.ENUM(*values, name=name, create_type=False)
    enum_type.create(bind, checkfirst=True)
    return enum_type


def upgrade() -> None:
    bind = op.get_bind()
    if bind.dialect.name == "postgresql":
        op.execute("ALTER TYPE hazard_type ADD VALUE IF NOT EXISTS 'PARTIALLY_ACCESSIBLE'")

    entity_type = _enum(SYNC_ENTITY_TYPES, "sync_entity_type")
    operation_type = _enum(SYNC_OPERATION_TYPES, "sync_operation_type")
    queue_status = _enum(SYNC_QUEUE_STATUSES, "sync_queue_status")
    resolution = _enum(CONFLICT_RESOLUTIONS, "conflict_resolution_kind")

    op.create_table(
        "sync_operations",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("operation_id", sa.Uuid(), nullable=False),
        sa.Column("device_id", sa.String(length=64), nullable=False),
        sa.Column("actor_id", sa.String(length=128), nullable=False),
        sa.Column("entity_type", entity_type, nullable=False),
        sa.Column("entity_id", sa.String(length=64), nullable=False),
        sa.Column("operation_type", operation_type, nullable=False),
        sa.Column("payload_json", sa.Text(), nullable=False),
        sa.Column("queue_status", queue_status, nullable=False),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column("logical_timestamp", sa.Integer(), nullable=False),
        sa.Column("parent_version", sa.Integer(), nullable=True),
        sa.Column("failure_reason", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id", name="pk_sync_operations"),
        sa.UniqueConstraint("operation_id", name="uq_sync_operations_operation_id"),
    )
    op.create_index("ix_sync_operations_operation_id", "sync_operations", ["operation_id"], unique=True)
    op.create_index("ix_sync_operations_device_id", "sync_operations", ["device_id"])
    op.create_index("ix_sync_operations_entity_id", "sync_operations", ["entity_id"])
    op.create_index("ix_sync_operations_entity", "sync_operations", ["entity_type", "entity_id"])

    op.create_table(
        "sync_conflicts",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("entity_type", entity_type, nullable=False),
        sa.Column("entity_id", sa.String(length=64), nullable=False),
        sa.Column("operation_a_id", sa.Uuid(), nullable=False),
        sa.Column("operation_b_id", sa.Uuid(), nullable=False),
        sa.Column("detected_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("resolution", resolution, nullable=False),
        sa.Column("winner_operation_id", sa.Uuid(), nullable=False),
        sa.Column("loser_operation_id", sa.Uuid(), nullable=False),
        sa.Column("reason", sa.Text(), nullable=False),
        sa.Column("resolved_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id", name="pk_sync_conflicts"),
    )
    op.create_index("ix_sync_conflicts_entity_id", "sync_conflicts", ["entity_id"])


def downgrade() -> None:
    op.drop_index("ix_sync_conflicts_entity_id", table_name="sync_conflicts")
    op.drop_table("sync_conflicts")
    op.drop_index("ix_sync_operations_entity", table_name="sync_operations")
    op.drop_index("ix_sync_operations_entity_id", table_name="sync_operations")
    op.drop_index("ix_sync_operations_device_id", table_name="sync_operations")
    op.drop_index("ix_sync_operations_operation_id", table_name="sync_operations")
    op.drop_table("sync_operations")
    bind = op.get_bind()
    for name in (
        "sync_entity_type",
        "sync_operation_type",
        "sync_queue_status",
        "conflict_resolution_kind",
    ):
        sa.Enum(name=name).drop(bind, checkfirst=True)
