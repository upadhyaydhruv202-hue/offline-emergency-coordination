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
