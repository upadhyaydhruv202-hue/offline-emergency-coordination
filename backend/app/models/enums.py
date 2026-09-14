"""Enumerations shared by the persistence and API layers."""

from __future__ import annotations

from enum import StrEnum


class UserRole(StrEnum):
    """Operational roles.

    Slice 1 keeps authorization coarse: a route declares the roles it accepts.
    Fine-grained permissions (per-incident scoping, delegated command, etc.)
    are a future slice and should be layered on top of this enum, not replace it.
    """

    RESCUE_TEAM = "RESCUE_TEAM"
    MEDICAL_TEAM = "MEDICAL_TEAM"
    VOLUNTEER = "VOLUNTEER"
    INCIDENT_COMMANDER = "INCIDENT_COMMANDER"
    ADMIN = "ADMIN"

    @property
    def label(self) -> str:
        return self.value.replace("_", " ").title()


COMMAND_ROLES: frozenset[UserRole] = frozenset({UserRole.INCIDENT_COMMANDER, UserRole.ADMIN})
FIELD_ROLES: frozenset[UserRole] = frozenset(
    {UserRole.RESCUE_TEAM, UserRole.MEDICAL_TEAM, UserRole.VOLUNTEER}
)


class TriageCategory(StrEnum):
    """START-style triage, reduced to what a responder can decide in seconds.

    Declaration order is severity order, which :attr:`priority` exposes for
    sorting. The command centre and the handset must agree on these values
    exactly: a record triaged on a device offline is uploaded verbatim.
    """

    CRITICAL = "CRITICAL"
    URGENT = "URGENT"
    MODERATE = "MODERATE"
    STABLE = "STABLE"

    @property
    def priority(self) -> int:
        """Sort key. Lower is more urgent, so critical cases surface first."""
        return list(TriageCategory).index(self)

    @property
    def label(self) -> str:
        return self.value.title()


class VictimStatus(StrEnum):
    """Where a casualty is in the response, not a clinical diagnosis."""

    REGISTERED = "REGISTERED"
    UNDER_TREATMENT = "UNDER_TREATMENT"
    AWAITING_EVACUATION = "AWAITING_EVACUATION"
    EVACUATED = "EVACUATED"
    DECEASED = "DECEASED"

    @property
    def is_closed(self) -> bool:
        """True once the casualty no longer needs field resources."""
        return self in {VictimStatus.EVACUATED, VictimStatus.DECEASED}

    @property
    def label(self) -> str:
        return self.value.replace("_", " ").capitalize()


class AgeGroup(StrEnum):
    INFANT = "INFANT"
    CHILD = "CHILD"
    ADULT = "ADULT"
    ELDERLY = "ELDERLY"
    UNKNOWN = "UNKNOWN"


class Gender(StrEnum):
    MALE = "MALE"
    FEMALE = "FEMALE"
    OTHER = "OTHER"
    UNKNOWN = "UNKNOWN"


class DisasterType(StrEnum):
    """What an incident is a response to.

    Deliberately coarse, because this is chosen from a dropdown in the first
    minutes of a response. ``OTHER`` is always present so an event that does
    not fit the list can never block an incident from being opened.
    """

    EARTHQUAKE = "EARTHQUAKE"
    FLOOD = "FLOOD"
    FIRE = "FIRE"
    LANDSLIDE = "LANDSLIDE"
    CYCLONE = "CYCLONE"
    INDUSTRIAL_ACCIDENT = "INDUSTRIAL_ACCIDENT"
    BUILDING_COLLAPSE = "BUILDING_COLLAPSE"
    OTHER = "OTHER"

    @property
    def label(self) -> str:
        return self.value.replace("_", " ").capitalize()


class IncidentStatus(StrEnum):
    """Whether an incident is still consuming field resources.

    ``PAUSED`` is not a nicety: a response is routinely suspended for
    nightfall or aftershock risk without being over, and a command centre
    that cannot say so has to choose between a lie and a resolved incident.
    """

    ACTIVE = "ACTIVE"
    PAUSED = "PAUSED"
    RESOLVED = "RESOLVED"

    @property
    def is_closed(self) -> bool:
        return self is IncidentStatus.RESOLVED

    @property
    def label(self) -> str:
        return self.value.capitalize()


class SosPriority(StrEnum):
    """How fast a responder's distress call needs someone moving.

    There is no LOW tier: a responder who raises an SOS is never a low
    priority. Declaration order is urgency order, exposed by :attr:`priority`.
    """

    CRITICAL = "CRITICAL"
    HIGH = "HIGH"
    MEDIUM = "MEDIUM"

    @property
    def priority(self) -> int:
        """Sort key where 1 is the most urgent.

        One-based, unlike :attr:`TriageCategory.priority`, because these
        numbers are read by humans on the SOS queue rather than only sorted.
        """
        return list(SosPriority).index(self) + 1

    @property
    def label(self) -> str:
        return self.value.capitalize()


class SosStatus(StrEnum):
    """The lifecycle of an SOS from the command centre's side.

    ``ACKNOWLEDGED`` is the important one: it tells the responder who raised
    the call that a human, not a queue, has seen it.
    """

    CREATED = "CREATED"
    ACKNOWLEDGED = "ACKNOWLEDGED"
    RESOLVED = "RESOLVED"

    @property
    def is_closed(self) -> bool:
        return self is SosStatus.RESOLVED

    @property
    def label(self) -> str:
        return self.value.capitalize()


class HazardType(StrEnum):
    """What a responder saw that makes an area dangerous.

    These are the hazards that change a route or an approach, which is why
    ``ROAD_BLOCKED`` and ``BRIDGE_RISK`` sit alongside the physical dangers.
    """

    FLOOD = "FLOOD"
    FIRE = "FIRE"
    SMOKE = "SMOKE"
    ROAD_BLOCKED = "ROAD_BLOCKED"
    PARTIALLY_ACCESSIBLE = "PARTIALLY_ACCESSIBLE"
    BUILDING_DAMAGE = "BUILDING_DAMAGE"
    BRIDGE_RISK = "BRIDGE_RISK"
    LANDSLIDE = "LANDSLIDE"
    ELECTRICAL_HAZARD = "ELECTRICAL_HAZARD"
    CHEMICAL_HAZARD = "CHEMICAL_HAZARD"
    OTHER = "OTHER"

    @property
    def label(self) -> str:
        return self.value.replace("_", " ").capitalize()


class HazardSeverity(StrEnum):
    """How dangerous the hazard is to anyone approaching it.

    Declaration order is severity order, exposed by :attr:`priority`.
    """

    CRITICAL = "CRITICAL"
    HIGH = "HIGH"
    MEDIUM = "MEDIUM"
    LOW = "LOW"

    @property
    def priority(self) -> int:
        """Sort key where 1 is the most severe."""
        return list(HazardSeverity).index(self) + 1

    @property
    def label(self) -> str:
        return self.value.capitalize()


class HazardStatus(StrEnum):
    """Whether a hazard is a single report or confirmed ground truth.

    A hazard is trusted enough to reroute a team on ``REPORTED``; the
    distinction from ``VERIFIED`` exists so the command centre can tell one
    responder's glance from a confirmed obstruction.
    """

    REPORTED = "REPORTED"
    VERIFIED = "VERIFIED"
    RESOLVED = "RESOLVED"

    @property
    def is_closed(self) -> bool:
        return self is HazardStatus.RESOLVED

    @property
    def label(self) -> str:
        return self.value.capitalize()


class TaskPriority(StrEnum):
    """How a task competes for the next free team.

    Declaration order is urgency order, exposed by :attr:`priority`.
    """

    CRITICAL = "CRITICAL"
    HIGH = "HIGH"
    MEDIUM = "MEDIUM"
    LOW = "LOW"

    @property
    def priority(self) -> int:
        """Sort key where 1 is the most urgent."""
        return list(TaskPriority).index(self) + 1

    @property
    def label(self) -> str:
        return self.value.capitalize()


class TaskStatus(StrEnum):
    """A task's progress as reported by whoever holds it.

    ``ACCEPTED`` and ``IN_PROGRESS`` are separate because a team that has
    taken a task but not reached the site is not yet working it, and the
    command centre reassigns on that difference.
    """

    PENDING = "PENDING"
    ACCEPTED = "ACCEPTED"
    IN_PROGRESS = "IN_PROGRESS"
    COMPLETED = "COMPLETED"
    CANCELLED = "CANCELLED"

    @property
    def is_closed(self) -> bool:
        """True once the task no longer needs a team assigned to it."""
        return self in {TaskStatus.COMPLETED, TaskStatus.CANCELLED}

    @property
    def label(self) -> str:
        return self.value.replace("_", " ").capitalize()


class ResponderStatus(StrEnum):
    """A responder's own availability, as they last reported it.

    Stored on ``responder_presences`` for the command-centre map. Field devices
    remain the authority while offline; this row is the last ingested copy.
    """

    AVAILABLE = "AVAILABLE"
    EN_ROUTE = "EN_ROUTE"
    ON_MISSION = "ON_MISSION"
    NEEDS_ASSISTANCE = "NEEDS_ASSISTANCE"
    OFF_DUTY = "OFF_DUTY"

    @property
    def label(self) -> str:
        return self.value.replace("_", " ").capitalize()


class FacilityKind(StrEnum):
    HOSPITAL = "HOSPITAL"
    SHELTER = "SHELTER"
    RESOURCE_CACHE = "RESOURCE_CACHE"

    @property
    def label(self) -> str:
        return self.value.replace("_", " ").capitalize()


class FacilityStatus(StrEnum):
    OPEN = "OPEN"
    LIMITED = "LIMITED"
    FULL = "FULL"
    CLOSED = "CLOSED"

    @property
    def label(self) -> str:
        return self.value.capitalize()


class AuditSeverity(StrEnum):
    INFO = "INFO"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"


class SyncEntityType(StrEnum):
    INCIDENT = "INCIDENT"
    VICTIM = "VICTIM"
    HAZARD = "HAZARD"
    TASK = "TASK"
    SOS = "SOS"
    RESPONDER_STATUS = "RESPONDER_STATUS"


class SyncOperationType(StrEnum):
    CREATE = "CREATE"
    UPDATE = "UPDATE"
    DELETE = "DELETE"


class SyncQueueStatus(StrEnum):
    PENDING = "PENDING"
    IN_FLIGHT = "IN_FLIGHT"
    ACKNOWLEDGED = "ACKNOWLEDGED"
    FAILED = "FAILED"
    CONFLICT = "CONFLICT"


class ConflictResolutionKind(StrEnum):
    LAST_WRITER_WINS = "LAST_WRITER_WINS"
    DEVICE_TIE_BREAK = "DEVICE_TIE_BREAK"
    OPERATION_TIE_BREAK = "OPERATION_TIE_BREAK"
    MERGED = "MERGED"
    MANUAL_REVIEW = "MANUAL_REVIEW"
