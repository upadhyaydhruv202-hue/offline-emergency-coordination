"""Slice 1: users table and role enum

Revision ID: 0001_initial_users
Revises:
Create Date: 2026-08-28
"""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0001_initial_users"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

USER_ROLES = (
    "RESCUE_TEAM",
    "MEDICAL_TEAM",
    "VOLUNTEER",
    "INCIDENT_COMMANDER",
    "ADMIN",
)


def _create_role_type() -> sa.types.TypeEngine[str]:
    """Return the type for ``users.role``, creating it first on PostgreSQL.

    A PostgreSQL enum is a standalone object. Creating it here with
    ``checkfirst`` lets the migration be re-run after a half-applied attempt,
    and ``create_type=False`` stops ``create_table`` from emitting a second,
    unconditional ``CREATE TYPE`` that would then fail. Dialects without native
    enums render the constraint inline and need no separate object.
    """
    bind = op.get_bind()
    if bind.dialect.name != "postgresql":
        return sa.Enum(*USER_ROLES, name="user_role")

    user_role = postgresql.ENUM(*USER_ROLES, name="user_role", create_type=False)
    user_role.create(bind, checkfirst=True)
    return user_role


def upgrade() -> None:
    user_role = _create_role_type()

    op.create_table(
        "users",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("email", sa.String(length=320), nullable=False),
        sa.Column("full_name", sa.String(length=160), nullable=False),
        sa.Column("hashed_password", sa.String(length=255), nullable=False),
        sa.Column("role", user_role, nullable=False),
        sa.Column("is_active", sa.Boolean(), server_default=sa.text("true"), nullable=False),
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
        sa.PrimaryKeyConstraint("id", name="pk_users"),
        sa.UniqueConstraint("email", name="uq_users_email"),
    )
    op.create_index("ix_users_email", "users", ["email"], unique=True)


def downgrade() -> None:
    op.drop_index("ix_users_email", table_name="users")
    op.drop_table("users")
    sa.Enum(name="user_role").drop(op.get_bind(), checkfirst=True)
