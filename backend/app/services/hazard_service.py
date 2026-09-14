"""Hazard use-cases.

The handset reports hazards, so this service is an idempotent receiver and a
read model for the command centre - the same stance as
:mod:`app.services.victim_service`.
"""

from __future__ import annotations

import uuid

from sqlalchemy.orm import Session

from app.core.errors import NotFoundError
from app.models.enums import HazardSeverity, HazardStatus, HazardType
from app.models.hazard import Hazard
from app.repositories.hazard_repository import HazardRepository
from app.repositories.incident_repository import IncidentRepository
from app.schemas.hazard import (
    HazardBoard,
    HazardCreate,
    HazardPage,
    HazardRead,
    HazardSeverityCounts,
    HazardStatusCounts,
    HazardUpdate,
)


class HazardService:
    def __init__(self, session: Session) -> None:
        self.session = session
        self.hazards = HazardRepository(session)
        self.incidents = IncidentRepository(session)

    def register(self, payload: HazardCreate) -> Hazard:
        """Store an uploaded hazard, or refresh the copy already held.

        A device with an intermittent link will retry an upload it is not sure
        landed. Re-sending the same UUID has to be harmless, so this updates
        in place instead of raising a conflict.
        """
        existing = self.hazards.get(payload.id)
        if existing is not None:
            return self._apply(existing, payload)

        self._require_known_incident(payload.incident_id)

        hazard = Hazard(
            id=payload.id,
            hazard_code=payload.hazard_code,
            incident_id=payload.incident_id,
            reported_by=payload.reported_by,
            type=payload.type,
            severity=payload.severity,
            priority=payload.severity.priority,
            description=_blank_to_none(payload.description),
            latitude=payload.latitude,
            longitude=payload.longitude,
            observed_at=payload.observed_at,
            status=payload.status,
        )
        if payload.created_at is not None:
            # Preserve when the device first recorded the report, which may be
            # hours before it found a link.
            hazard.created_at = payload.created_at

        created = self.hazards.add(hazard)
        self.session.commit()
        self.session.refresh(created)
        return created

    def update(self, hazard_id: uuid.UUID, payload: HazardUpdate) -> Hazard:
        return self._apply(self.get(hazard_id), payload)

    def get(self, hazard_id: uuid.UUID) -> Hazard:
        hazard = self.hazards.get(hazard_id)
        if hazard is None:
            raise NotFoundError("No hazard with that identifier")
        return hazard

    def page(
        self,
        *,
        search: str | None = None,
        hazard_type: HazardType | None = None,
        severity: HazardSeverity | None = None,
        status: HazardStatus | None = None,
        limit: int = 100,
        offset: int = 0,
    ) -> HazardPage:
        items = self.hazards.search(
            search=search,
            hazard_type=hazard_type,
            severity=severity,
            status=status,
            limit=limit,
            offset=offset,
        )
        return HazardPage(
            items=[HazardRead.model_validate(hazard) for hazard in items],
            total=self.hazards.count(
                search=search, hazard_type=hazard_type, severity=severity, status=status
            ),
        )

    def board(self) -> HazardBoard:
        """Counts across every hazard, ignoring whatever filter is applied.

        A command centre filtering to RESOLVED still needs to see that two
        critical hazards are outstanding.
        """
        by_severity = self.hazards.count_by_severity()
        by_status = self.hazards.count_by_status()

        return HazardBoard(
            total=sum(by_severity.values()),
            by_severity=HazardSeverityCounts(
                critical=by_severity[HazardSeverity.CRITICAL],
                high=by_severity[HazardSeverity.HIGH],
                medium=by_severity[HazardSeverity.MEDIUM],
                low=by_severity[HazardSeverity.LOW],
            ),
            by_status=HazardStatusCounts(
                reported=by_status[HazardStatus.REPORTED],
                verified=by_status[HazardStatus.VERIFIED],
                resolved=by_status[HazardStatus.RESOLVED],
            ),
        )

    def _apply(self, hazard: Hazard, payload: HazardCreate | HazardUpdate) -> Hazard:
        # Read attributes rather than dumping: a dump would flatten the enums
        # to plain strings and lose `HazardSeverity.priority`. Only the fields
        # the caller actually sent are touched, so a PATCH stays partial.
        changed = payload.model_fields_set - _IMMUTABLE
        if "incident_id" in changed:
            self._require_known_incident(payload.incident_id)

        for field in changed:
            value = getattr(payload, field)
            setattr(hazard, field, _blank_to_none(value) if type(value) is str else value)

        if "severity" in changed:
            hazard.priority = hazard.severity.priority

        self.session.add(hazard)
        self.session.commit()
        self.session.refresh(hazard)
        return hazard

    def _require_known_incident(self, incident_id: uuid.UUID | None) -> None:
        """Reject a link to an incident this peer has never received.

        The foreign key would raise an opaque integrity error instead, and the
        fix is the same either way: upload the incident first.
        """
        if incident_id is None:
            return
        if self.incidents.get(incident_id) is None:
            raise NotFoundError(
                "No incident with that identifier",
                details={"incident_id": str(incident_id)},
            )


def _blank_to_none(value: str | None) -> str | None:
    """Treat an empty field as unrecorded rather than as an empty string."""
    if value is None:
        return None
    stripped = value.strip()
    return stripped or None


# Identity and provenance travel with the record from the device; an update
# may not rewrite them. ``priority`` is excluded because it is derived from
# ``severity`` rather than reported.
_IMMUTABLE = frozenset({"id", "hazard_code", "reported_by", "created_at", "priority"})
