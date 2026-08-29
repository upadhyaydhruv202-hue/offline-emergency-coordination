"""Slice 2: victims table with triage and status enums

Revision ID: 0002_victims
Revises: 0001_initial_users
Create Date: 2026-08-29
"""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0002_victims"
down_revision: str | None = "0001_initial_users"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

TRIAGE_CATEGORIES = ("CRITICAL", "URGENT", "MODERATE", "STABLE")
VICTIM_STATUSES = (
    "REGISTERED",
    "UNDER_TREATMENT",
    "AWAITING_EVACUATION",
    "EVACUATED",
    "DECEASED",
)
AGE_GROUPS = ("INFANT", "CHILD", "ADULT", "ELDERLY", "UNKNOWN")
GENDERS = ("MALE", "FEMALE", "OTHER", "UNKNOWN")


def _enum(values: tuple[str, ...], name: str) -> sa.types.TypeEngine[str]:
    """Return the column type, creating the type object first on PostgreSQL.

    Same reasoning as the users migration: a PostgreSQL enum is a standalone
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
    triage_category = _enum(TRIAGE_CATEGORIES, "triage_category")
    victim_status = _enum(VICTIM_STATUSES, "victim_status")
    age_group = _enum(AGE_GROUPS, "age_group")
    gender = _enum(GENDERS, "gender")

    op.create_table(
        "victims",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("temporary_id", sa.String(length=32), nullable=False),
        sa.Column("name", sa.String(length=160), nullable=True),
        sa.Column("age", sa.Integer(), nullable=True),
        sa.Column("age_group", age_group, nullable=False),
        sa.Column("gender", gender, nullable=False),
        sa.Column("medical_condition", sa.Text(), nullable=True),
        sa.Column("injury_type", sa.String(length=200), nullable=True),
        sa.Column("triage_category", triage_category, nullable=False),
        sa.Column("priority", sa.Integer(), nullable=False),
        sa.Column("assistance_required", sa.Text(), nullable=True),
        sa.Column("status", victim_status, nullable=False),
        sa.Column("latitude", sa.Float(), nullable=True),
        sa.Column("longitude", sa.Float(), nullable=True),
        sa.Column("created_by", sa.String(length=64), nullable=False),
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
        sa.PrimaryKeyConstraint("id", name="pk_victims"),
        sa.UniqueConstraint("temporary_id", name="uq_victims_temporary_id"),
    )
    op.create_index("ix_victims_temporary_id", "victims", ["temporary_id"], unique=True)
    # Serves the default listing: severity first, then most recently touched.
    op.create_index("ix_victims_priority_updated_at", "victims", ["priority", "updated_at"])


def downgrade() -> None:
    op.drop_index("ix_victims_priority_updated_at", table_name="victims")
    op.drop_index("ix_victims_temporary_id", table_name="victims")
    op.drop_table("victims")

    bind = op.get_bind()
    for name in ("triage_category", "victim_status", "age_group", "gender"):
        sa.Enum(name=name).drop(bind, checkfirst=True)
