"""Database access for :class:`~app.models.incident.Incident`."""

from __future__ import annotations

from sqlalchemy import func, or_, select

from app.models.enums import DisasterType, IncidentStatus
from app.models.incident import Incident
from app.repositories.base import BaseRepository


class IncidentRepository(BaseRepository[Incident]):
    model = Incident

    def get_by_code(self, incident_code: str) -> Incident | None:
        stmt = select(Incident).where(Incident.incident_code == incident_code.strip())
        return self.session.scalars(stmt).first()

    def search(
        self,
        *,
        search: str | None = None,
        disaster_type: DisasterType | None = None,
        status: IncidentStatus | None = None,
        limit: int = 100,
        offset: int = 0,
    ) -> list[Incident]:
        """Most recently declared first.

        Incidents carry no severity of their own - the urgency lives in the
        hazards, SOS events and tasks filed against them - so recency is the
        only ordering that means anything here.
        """
        stmt = (
            self._filtered(search=search, disaster_type=disaster_type, status=status)
            .order_by(Incident.created_at.desc())
            .limit(limit)
            .offset(offset)
        )
        return list(self.session.scalars(stmt))

    def count(
        self,
        *,
        search: str | None = None,
        disaster_type: DisasterType | None = None,
        status: IncidentStatus | None = None,
    ) -> int:
        stmt = self._filtered(
            search=search, disaster_type=disaster_type, status=status
        ).with_only_columns(func.count(Incident.id))
        return self.session.scalar(stmt) or 0

    def count_by_status(self) -> dict[IncidentStatus, int]:
        """Totals for every status, including the ones with no incidents."""
        stmt = select(Incident.status, func.count(Incident.id)).group_by(Incident.status)
        counted = dict.fromkeys(IncidentStatus, 0)
        for status, total in self.session.execute(stmt):
            counted[IncidentStatus(status)] = total
        return counted

    def _filtered(
        self,
        *,
        search: str | None,
        disaster_type: DisasterType | None,
        status: IncidentStatus | None,
    ):
        stmt = select(Incident)
        if disaster_type is not None:
            stmt = stmt.where(Incident.disaster_type == disaster_type)
        if status is not None:
            stmt = stmt.where(Incident.status == status)

        term = (search or "").strip()
        if term:
            # What a radio operator has to hand: the code, the name it is
            # being called by, or the zone it was declared in.
            pattern = f"%{term.lower()}%"
            stmt = stmt.where(
                or_(
                    func.lower(Incident.incident_code).like(pattern),
                    func.lower(Incident.title).like(pattern),
                    func.lower(Incident.assigned_zone).like(pattern),
                )
            )
        return stmt
