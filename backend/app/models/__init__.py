"""ORM models.

Six tables so far: ``users`` (Slice 1), ``victims`` (Slice 2) and the field
operations set - ``incidents``, ``hazards``, ``sos_events``, ``tasks``
(Slice 3). The entities required by later slices - locations,
sync_operations, sync_conflicts, audit_events - are documented in
``docs/architecture.md`` and are added as separate modules plus Alembic
revisions when their slice lands. Nothing here is stubbed out.
"""

from app.models.base import Base, TimestampMixin, UuidPrimaryKeyMixin
from app.models.enums import (
    COMMAND_ROLES,
    FIELD_ROLES,
    AgeGroup,
    DisasterType,
    Gender,
    HazardSeverity,
    HazardStatus,
    HazardType,
    IncidentStatus,
    ResponderStatus,
    SosPriority,
    SosStatus,
    TaskPriority,
    TaskStatus,
    TriageCategory,
    UserRole,
    VictimStatus,
)
from app.models.hazard import Hazard
from app.models.incident import Incident
from app.models.sos_event import SosEvent
from app.models.task import Task
from app.models.user import User
from app.models.victim import Victim

__all__ = [
    "AgeGroup",
    "Base",
    "COMMAND_ROLES",
    "DisasterType",
    "FIELD_ROLES",
    "Gender",
    "Hazard",
    "HazardSeverity",
    "HazardStatus",
    "HazardType",
    "Incident",
    "IncidentStatus",
    "ResponderStatus",
    "SosEvent",
    "SosPriority",
    "SosStatus",
    "Task",
    "TaskPriority",
    "TaskStatus",
    "TimestampMixin",
    "TriageCategory",
    "User",
    "UserRole",
    "UuidPrimaryKeyMixin",
    "Victim",
    "VictimStatus",
]
