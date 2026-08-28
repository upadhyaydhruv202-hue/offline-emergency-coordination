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
