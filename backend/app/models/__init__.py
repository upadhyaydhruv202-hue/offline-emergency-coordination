"""ORM models.

Two tables so far: ``users`` (Slice 1) and ``victims`` (Slice 2). The entities
required by later slices - incidents, sos_events, hazards, responders, tasks,
locations, sync_operations, sync_conflicts, audit_events - are documented in
``docs/architecture.md`` and are added as separate modules plus Alembic
revisions when their slice lands. Nothing here is stubbed out.
"""

from app.models.base import Base, TimestampMixin, UuidPrimaryKeyMixin
from app.models.enums import (
    COMMAND_ROLES,
    FIELD_ROLES,
    AgeGroup,
    Gender,
    TriageCategory,
    UserRole,
    VictimStatus,
)
from app.models.user import User
from app.models.victim import Victim

__all__ = [
    "AgeGroup",
    "Base",
    "COMMAND_ROLES",
    "FIELD_ROLES",
    "Gender",
    "TimestampMixin",
    "TriageCategory",
    "User",
    "UserRole",
    "UuidPrimaryKeyMixin",
    "Victim",
    "VictimStatus",
]
