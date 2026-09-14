"""Incident use-cases.

The handset declares incidents, so this service is an idempotent receiver and
a read model for the command centre - the same stance as
:mod:`app.services.victim_service`. It cannot reject an incident that is
already being responded to in the field.
"""

from __future__ import annotations

import uuid

from sqlalchemy.orm import Session

from app.core.errors import NotFoundError
from app.models.enums import DisasterType, IncidentStatus
from app.models.incident import Incident
from app.repositories.incident_repository import IncidentRepository
from app.schemas.incident import (
    IncidentBoard,
    IncidentCreate,
    IncidentPage,
    IncidentRead,
    IncidentStatusCounts,
    IncidentUpdate,
)


class IncidentService:
    def __init__(self, session: Session) -> None:
        self.session = session
        self.incidents = IncidentRepository(session)

    def register(self, payload: IncidentCreate) -> Incident:
        """Store an uploaded incident, or refresh the copy already held.

        A device with an intermittent link will retry an upload it is not sure
        landed. Re-sending the same UUID has to be harmless, so this updates
        in place instead of raising a conflict.
        """
        existing = self.incidents.get(payload.id)
        if existing is not None:
            return self._apply(existing, payload)

        incident = Incident(
            id=payload.id,
            incident_code=payload.incident_code,
            title=payload.title,
            disaster_type=payload.disaster_type,
            description=_blank_to_none(payload.description),
            status=payload.status,
            assigned_zone=_blank_to_none(payload.assigned_zone),
            latitude=payload.latitude,
            longitude=payload.longitude,
            created_by=payload.created_by,
            last_modified_by=_blank_to_none(payload.last_modified_by),
        )
        if payload.created_at is not None:
            # Preserve when the incident was actually declared, which may be
            # hours before the device found a link.
            incident.created_at = payload.created_at

        created = self.incidents.add(incident)
        self.session.commit()
        self.session.refresh(created)
        return created

    def update(self, incident_id: uuid.UUID, payload: IncidentUpdate) -> Incident:
        return self._apply(self.get(incident_id), payload)

    def get(self, incident_id: uuid.UUID) -> Incident:
        incident = self.incidents.get(incident_id)
        if incident is None:
            raise NotFoundError("No incident with that identifier")
        return incident

    def page(
        self,
        *,
        search: str | None = None,
        disaster_type: DisasterType | None = None,
        status: IncidentStatus | None = None,
        limit: int = 100,
        offset: int = 0,
    ) -> IncidentPage:
        items = self.incidents.search(
            search=search,
            disaster_type=disaster_type,
            status=status,
            limit=limit,
            offset=offset,
        )
        return IncidentPage(
            items=[IncidentRead.model_validate(incident) for incident in items],
            total=self.incidents.count(search=search, disaster_type=disaster_type, status=status),
        )

    def board(self) -> IncidentBoard:
        """Counts across every incident, ignoring whatever filter is applied.

        A command centre filtering to RESOLVED still needs to see how many
        responses are running.
        """
        by_status = self.incidents.count_by_status()

        return IncidentBoard(
            total=sum(by_status.values()),
            by_status=IncidentStatusCounts(
                active=by_status[IncidentStatus.ACTIVE],
                paused=by_status[IncidentStatus.PAUSED],
                resolved=by_status[IncidentStatus.RESOLVED],
            ),
        )

    def _apply(self, incident: Incident, payload: IncidentCreate | IncidentUpdate) -> Incident:
        # Read attributes rather than dumping: a dump would flatten the enums
        # to plain strings. Only the fields the caller actually sent are
        # touched, so a PATCH stays partial.
        changed = payload.model_fields_set - _IMMUTABLE
        for field in changed:
            value = getattr(payload, field)
            setattr(incident, field, _blank_to_none(value) if type(value) is str else value)

        self.session.add(incident)
        self.session.commit()
        self.session.refresh(incident)
        return incident


def _blank_to_none(value: str | None) -> str | None:
    """Treat an empty field as unrecorded rather than as an empty string."""
    if value is None:
        return None
    stripped = value.strip()
    return stripped or None


# Identity and provenance travel with the record from the device; an update
# may not rewrite them. ``last_modified_by`` is absent on purpose - it is the
# one provenance field an update is supposed to set.
_IMMUTABLE = frozenset({"id", "incident_code", "created_by", "created_at"})
