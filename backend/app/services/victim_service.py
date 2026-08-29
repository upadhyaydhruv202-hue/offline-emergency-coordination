"""Victim use-cases.

The mobile app owns victim *creation*: a record arrives here having already
been written to a device's SQLite and shown to a responder. This service is
therefore an idempotent receiver and a read model for the command centre, not
an authority that can reject a casualty out of existence.
"""

from __future__ import annotations

import uuid

from sqlalchemy.orm import Session

from app.core.errors import NotFoundError
from app.models.enums import TriageCategory, VictimStatus
from app.models.victim import Victim
from app.repositories.victim_repository import VictimRepository
from app.schemas.victim import (
    TriageCounts,
    VictimBoard,
    VictimCreate,
    VictimPage,
    VictimRead,
    VictimUpdate,
)


class VictimService:
    def __init__(self, session: Session) -> None:
        self.session = session
        self.victims = VictimRepository(session)

    def register(self, payload: VictimCreate) -> Victim:
        """Store an uploaded record, or refresh the copy already held.

        A device with an intermittent link will retry an upload it is not sure
        landed. Re-sending the same UUID has to be harmless, so this updates
        in place instead of raising a conflict.
        """
        existing = self.victims.get(payload.id)
        if existing is not None:
            return self._apply(existing, payload)

        victim = Victim(
            id=payload.id,
            temporary_id=payload.temporary_id,
            name=_blank_to_none(payload.name),
            age=payload.age,
            age_group=payload.age_group,
            gender=payload.gender,
            medical_condition=_blank_to_none(payload.medical_condition),
            injury_type=_blank_to_none(payload.injury_type),
            triage_category=payload.triage_category,
            priority=payload.triage_category.priority,
            assistance_required=_blank_to_none(payload.assistance_required),
            status=payload.status,
            latitude=payload.latitude,
            longitude=payload.longitude,
            created_by=payload.created_by,
        )
        if payload.created_at is not None:
            # Preserve when the responder actually registered them, which may
            # be hours before the device found a link.
            victim.created_at = payload.created_at

        created = self.victims.add(victim)
        self.session.commit()
        self.session.refresh(created)
        return created

    def update(self, victim_id: uuid.UUID, payload: VictimUpdate) -> Victim:
        return self._apply(self.get(victim_id), payload)

    def get(self, victim_id: uuid.UUID) -> Victim:
        victim = self.victims.get(victim_id)
        if victim is None:
            raise NotFoundError("No victim with that identifier")
        return victim

    def page(
        self,
        *,
        search: str | None = None,
        triage: TriageCategory | None = None,
        status: VictimStatus | None = None,
        limit: int = 100,
        offset: int = 0,
    ) -> VictimPage:
        items = self.victims.search(
            search=search, triage=triage, status=status, limit=limit, offset=offset
        )
        return VictimPage(
            items=[VictimRead.model_validate(victim) for victim in items],
            board=self.board(),
            total=self.victims.count(search=search, triage=triage, status=status),
        )

    def board(self) -> VictimBoard:
        """Counts across every record, ignoring whatever filter is applied.

        A command centre filtering to STABLE still needs to see that four
        criticals are outstanding.
        """
        by_triage = self.victims.count_by_triage()
        by_status = self.victims.count_by_status()
        closed = sum(total for status, total in by_status.items() if status.is_closed)
        total = sum(by_triage.values())

        return VictimBoard(
            total=total,
            open_cases=total - closed,
            evacuated=by_status[VictimStatus.EVACUATED],
            by_triage=TriageCounts(
                critical=by_triage[TriageCategory.CRITICAL],
                urgent=by_triage[TriageCategory.URGENT],
                moderate=by_triage[TriageCategory.MODERATE],
                stable=by_triage[TriageCategory.STABLE],
            ),
        )

    def _apply(self, victim: Victim, payload: VictimCreate | VictimUpdate) -> Victim:
        # Read attributes rather than dumping: a dump would flatten the enums
        # to plain strings and lose `TriageCategory.priority`. Only the fields
        # the caller actually sent are touched, so a PATCH stays partial.
        changed = payload.model_fields_set - _IMMUTABLE
        for field in changed:
            value = getattr(payload, field)
            setattr(victim, field, _blank_to_none(value) if type(value) is str else value)

        if "triage_category" in changed:
            victim.priority = victim.triage_category.priority

        self.session.add(victim)
        self.session.commit()
        self.session.refresh(victim)
        return victim


def _blank_to_none(value: str | None) -> str | None:
    """Treat an empty field as unrecorded rather than as an empty string."""
    if value is None:
        return None
    stripped = value.strip()
    return stripped or None


# Identity and provenance travel with the record from the device; an update
# may not rewrite them.
_IMMUTABLE = frozenset({"id", "temporary_id", "created_by", "created_at", "priority"})
