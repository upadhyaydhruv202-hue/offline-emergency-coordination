"""SOS use-cases.

The handset raises the call, so this service is an idempotent receiver and a
read model for the command centre - the same stance as
:mod:`app.services.victim_service`. Nothing here may refuse a distress call.
"""

from __future__ import annotations

import uuid

from sqlalchemy.orm import Session

from app.core.errors import NotFoundError
from app.models.enums import SosPriority, SosStatus
from app.models.sos_event import SosEvent
from app.repositories.incident_repository import IncidentRepository
from app.repositories.sos_event_repository import SosEventRepository
from app.schemas.sos_event import (
    SosBoard,
    SosEventCreate,
    SosEventPage,
    SosEventRead,
    SosEventUpdate,
    SosPriorityCounts,
    SosStatusCounts,
)


class SosService:
    def __init__(self, session: Session) -> None:
        self.session = session
        self.sos_events = SosEventRepository(session)
        self.incidents = IncidentRepository(session)

    def register(self, payload: SosEventCreate) -> SosEvent:
        """Store an uploaded SOS, or refresh the copy already held.

        A device with an intermittent link will retry an upload it is not sure
        landed. Re-sending the same UUID has to be harmless, so this updates
        in place instead of raising a conflict.
        """
        existing = self.sos_events.get(payload.id)
        if existing is not None:
            return self._apply(existing, payload)

        self._require_known_incident(payload.incident_id)

        sos_event = SosEvent(
            id=payload.id,
            sos_code=payload.sos_code,
            incident_id=payload.incident_id,
            created_by=payload.created_by,
            latitude=payload.latitude,
            longitude=payload.longitude,
            raised_at=payload.raised_at,
            priority=payload.priority,
            message=_blank_to_none(payload.message),
            status=payload.status,
        )
        if payload.created_at is not None:
            # Preserve when the device first recorded the call, which may be
            # hours before it found a link.
            sos_event.created_at = payload.created_at

        created = self.sos_events.add(sos_event)
        self.session.commit()
        self.session.refresh(created)
        return created

    def update(self, sos_event_id: uuid.UUID, payload: SosEventUpdate) -> SosEvent:
        return self._apply(self.get(sos_event_id), payload)

    def get(self, sos_event_id: uuid.UUID) -> SosEvent:
        sos_event = self.sos_events.get(sos_event_id)
        if sos_event is None:
            raise NotFoundError("No SOS event with that identifier")
        return sos_event

    def page(
        self,
        *,
        priority: SosPriority | None = None,
        status: SosStatus | None = None,
        limit: int = 100,
        offset: int = 0,
    ) -> SosEventPage:
        items = self.sos_events.search(
            priority=priority, status=status, limit=limit, offset=offset
        )
        return SosEventPage(
            items=[SosEventRead.model_validate(sos_event) for sos_event in items],
            total=self.sos_events.count(priority=priority, status=status),
        )

    def board(self) -> SosBoard:
        """Counts across every call, ignoring whatever filter is applied.

        A command centre filtering to RESOLVED still needs to see that a
        critical call is unacknowledged.
        """
        by_priority = self.sos_events.count_by_priority()
        by_status = self.sos_events.count_by_status()

        return SosBoard(
            total=sum(by_priority.values()),
            by_priority=SosPriorityCounts(
                critical=by_priority[SosPriority.CRITICAL],
                high=by_priority[SosPriority.HIGH],
                medium=by_priority[SosPriority.MEDIUM],
            ),
            by_status=SosStatusCounts(
                created=by_status[SosStatus.CREATED],
                acknowledged=by_status[SosStatus.ACKNOWLEDGED],
                resolved=by_status[SosStatus.RESOLVED],
            ),
        )

    def _apply(self, sos_event: SosEvent, payload: SosEventCreate | SosEventUpdate) -> SosEvent:
        # Read attributes rather than dumping: a dump would flatten the enums
        # to plain strings. Only the fields the caller actually sent are
        # touched, so a PATCH stays partial.
        changed = payload.model_fields_set - _IMMUTABLE
        if "incident_id" in changed:
            self._require_known_incident(payload.incident_id)

        for field in changed:
            value = getattr(payload, field)
            setattr(sos_event, field, _blank_to_none(value) if type(value) is str else value)

        self.session.add(sos_event)
        self.session.commit()
        self.session.refresh(sos_event)
        return sos_event

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
# may not rewrite them.
_IMMUTABLE = frozenset({"id", "sos_code", "created_by", "created_at"})
