"""ORM models.

Slice 1 intentionally ships a single table (``users``). The entities required
by later slices - incidents, victims, triage_records, sos_events, hazards,
responders, tasks, locations, sync_operations, sync_conflicts, audit_events -
are documented in ``docs/architecture.md`` and are added as separate modules
plus Alembic revisions when their slice lands. Nothing here is stubbed out.
"""

from app.models.base import Base, TimestampMixin, UuidPrimaryKeyMixin
from app.models.enums import COMMAND_ROLES, FIELD_ROLES, UserRole
from app.models.user import User

__all__ = [
    "Base",
    "COMMAND_ROLES",
    "FIELD_ROLES",
    "TimestampMixin",
    "User",
    "UserRole",
    "UuidPrimaryKeyMixin",
]
