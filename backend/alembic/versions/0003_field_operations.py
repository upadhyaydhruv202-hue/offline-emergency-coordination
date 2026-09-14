"""Slice 3: field operations - incidents, hazards, SOS events and tasks

Purely additive: four new tables and their enum types. Nothing existing is
altered or deleted, so applying this on top of a populated ``victims`` or
``users`` table is safe.

``responder_status`` is created here even though no column references it yet.
The whole field-operations vocabulary is defined in one revision so the type
names cannot drift apart as the roster gains a self-reported availability
column in a later slice.

Revision ID: 0003_field_operations
Revises: 0002_victims
Create Date: 2026-09-13
"""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0003_field_operations"
down_revision: str | None = "0002_victims"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

DISASTER_TYPES = (
    "EARTHQUAKE",
    "FLOOD",
    "FIRE",
    "LANDSLIDE",
    "CYCLONE",
    "INDUSTRIAL_ACCIDENT",
    "BUILDING_COLLAPSE",
    "OTHER",
)
INCIDENT_STATUSES = ("ACTIVE", "PAUSED", "RESOLVED")
SOS_PRIORITIES = ("CRITICAL", "HIGH", "MEDIUM")
SOS_STATUSES = ("CREATED", "ACKNOWLEDGED", "RESOLVED")
HAZARD_TYPES = (
    "FLOOD",
    "FIRE",
    "SMOKE",
    "ROAD_BLOCKED",
    "BUILDING_DAMAGE",
    "BRIDGE_RISK",
    "LANDSLIDE",
    "ELECTRICAL_HAZARD",
    "CHEMICAL_HAZARD",
    "OTHER",
)
HAZARD_SEVERITIES = ("CRITICAL", "HIGH", "MEDIUM", "LOW")
HAZARD_STATUSES = ("REPORTED", "VERIFIED", "RESOLVED")
TASK_PRIORITIES = ("CRITICAL", "HIGH", "MEDIUM", "LOW")
TASK_STATUSES = ("PENDING", "ACCEPTED", "IN_PROGRESS", "COMPLETED", "CANCELLED")
RESPONDER_STATUSES = ("AVAILABLE", "EN_ROUTE", "ON_MISSION", "NEEDS_ASSISTANCE", "OFF_DUTY")

ENUM_NAMES = (
    "disaster_type",
    "incident_status",
    "sos_priority",
    "sos_status",
    "hazard_type",
    "hazard_severity",
    "hazard_status",
    "task_priority",
    "task_status",
    "responder_status",
)


def _enum(values: tuple[str, ...], name: str) -> sa.types.TypeEngine[str]:
    """Return the column type, creating the type object first on PostgreSQL.

    Same reasoning as the victims migration: a PostgreSQL enum is a standalone
    object, so it is created here with ``checkfirst`` and then referenced with
    ``create_type=False`` to stop ``create_table`` emitting a second,
    unconditional ``CREATE TYPE``.
    """
    bind = op.get_bind()
    if bind.dialect.name != "postgresql":
        return sa.Enum(*values, name=name)

    enum_type = postgresql.ENUM(*values, name=name, create_type=False)
    enum_type.create(bind, checkfirst=True)
    return enum_type


def upgrade() -> None:
    disaster_type = _enum(DISASTER_TYPES, "disaster_type")
    incident_status = _enum(INCIDENT_STATUSES, "incident_status")
    sos_priority = _enum(SOS_PRIORITIES, "sos_priority")
    sos_status = _enum(SOS_STATUSES, "sos_status")
    hazard_type = _enum(HAZARD_TYPES, "hazard_type")
    hazard_severity = _enum(HAZARD_SEVERITIES, "hazard_severity")
    hazard_status = _enum(HAZARD_STATUSES, "hazard_status")
    task_priority = _enum(TASK_PRIORITIES, "task_priority")
    task_status = _enum(TASK_STATUSES, "task_status")
    _enum(RESPONDER_STATUSES, "responder_status")

    op.create_table(
        "incidents",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("incident_code", sa.String(length=32), nullable=False),
        sa.Column("title", sa.String(length=200), nullable=False),
        sa.Column("disaster_type", disaster_type, nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("status", incident_status, nullable=False),
        sa.Column("assigned_zone", sa.String(length=120), nullable=True),
        sa.Column("latitude", sa.Float(), nullable=True),
        sa.Column("longitude", sa.Float(), nullable=True),
        sa.Column("created_by", sa.String(length=64), nullable=False),
        sa.Column("last_modified_by", sa.String(length=64), nullable=True),
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
        sa.PrimaryKeyConstraint("id", name="pk_incidents"),
        sa.UniqueConstraint("incident_code", name="uq_incidents_incident_code"),
    )
    op.create_index("ix_incidents_incident_code", "incidents", ["incident_code"], unique=True)

    op.create_table(
        "sos_events",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("sos_code", sa.String(length=32), nullable=False),
        sa.Column("incident_id", sa.Uuid(), nullable=True),
        sa.Column("created_by", sa.String(length=64), nullable=False),
        sa.Column("latitude", sa.Float(), nullable=True),
        sa.Column("longitude", sa.Float(), nullable=True),
        sa.Column("raised_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("priority", sos_priority, nullable=False),
        sa.Column("message", sa.Text(), nullable=True),
        sa.Column("status", sos_status, nullable=False),
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
        # SET NULL rather than CASCADE: a responder in trouble is never
        # discarded because the incident they were working was removed.
        sa.ForeignKeyConstraint(
            ["incident_id"],
            ["incidents.id"],
            name="fk_sos_events_incident_id_incidents",
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_sos_events"),
        sa.UniqueConstraint("sos_code", name="uq_sos_events_sos_code"),
    )
    op.create_index("ix_sos_events_sos_code", "sos_events", ["sos_code"], unique=True)
    # Serves the default listing: urgency first, then most recently raised.
    op.create_index(
        "ix_sos_events_priority_raised_at", "sos_events", ["priority", "raised_at"]
    )

    op.create_table(
        "hazards",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("hazard_code", sa.String(length=32), nullable=False),
        sa.Column("incident_id", sa.Uuid(), nullable=True),
        sa.Column("reported_by", sa.String(length=64), nullable=False),
        sa.Column("type", hazard_type, nullable=False),
        sa.Column("severity", hazard_severity, nullable=False),
        sa.Column("priority", sa.Integer(), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("latitude", sa.Float(), nullable=True),
        sa.Column("longitude", sa.Float(), nullable=True),
        sa.Column("observed_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("status", hazard_status, nullable=False),
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
        # SET NULL: a blocked road stays a blocked road after the incident
        # that prompted the report is gone.
        sa.ForeignKeyConstraint(
            ["incident_id"],
            ["incidents.id"],
            name="fk_hazards_incident_id_incidents",
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_hazards"),
        sa.UniqueConstraint("hazard_code", name="uq_hazards_hazard_code"),
    )
    op.create_index("ix_hazards_hazard_code", "hazards", ["hazard_code"], unique=True)
    # Severity first, then most recently observed, on the denormalised integer.
    op.create_index("ix_hazards_priority_observed_at", "hazards", ["priority", "observed_at"])

    op.create_table(
        "tasks",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("task_code", sa.String(length=32), nullable=False),
        sa.Column("incident_id", sa.Uuid(), nullable=True),
        sa.Column("assigned_to", sa.String(length=64), nullable=True),
        sa.Column("title", sa.String(length=200), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("priority", task_priority, nullable=False),
        sa.Column("rank", sa.Integer(), nullable=False),
        sa.Column("status", task_status, nullable=False),
        sa.Column("location", sa.String(length=200), nullable=True),
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
        # SET NULL: an orphaned task is still work someone may have to do.
        sa.ForeignKeyConstraint(
            ["incident_id"],
            ["incidents.id"],
            name="fk_tasks_incident_id_incidents",
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_tasks"),
        sa.UniqueConstraint("task_code", name="uq_tasks_task_code"),
    )
    op.create_index("ix_tasks_task_code", "tasks", ["task_code"], unique=True)


def downgrade() -> None:
    # Children before parents so the foreign keys to ``incidents`` hold.
    op.drop_index("ix_tasks_task_code", table_name="tasks")
    op.drop_table("tasks")

    op.drop_index("ix_hazards_priority_observed_at", table_name="hazards")
    op.drop_index("ix_hazards_hazard_code", table_name="hazards")
    op.drop_table("hazards")

    op.drop_index("ix_sos_events_priority_raised_at", table_name="sos_events")
    op.drop_index("ix_sos_events_sos_code", table_name="sos_events")
    op.drop_table("sos_events")

    op.drop_index("ix_incidents_incident_code", table_name="incidents")
    op.drop_table("incidents")

    bind = op.get_bind()
    for name in ENUM_NAMES:
        sa.Enum(name=name).drop(bind, checkfirst=True)
