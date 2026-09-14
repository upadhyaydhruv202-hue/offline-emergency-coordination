"""Database access for :class:`~app.models.sos_event.SosEvent`."""

from __future__ import annotations

from sqlalchemy import func, select

from app.models.enums import SosPriority, SosStatus
from app.models.sos_event import SosEvent
from app.repositories.base import BaseRepository


class SosEventRepository(BaseRepository[SosEvent]):
    model = SosEvent

    def get_by_code(self, sos_code: str) -> SosEvent | None:
        stmt = select(SosEvent).where(SosEvent.sos_code == sos_code.strip())
        return self.session.scalars(stmt).first()

    def search(
        self,
        *,
        priority: SosPriority | None = None,
        status: SosStatus | None = None,
        limit: int = 100,
        offset: int = 0,
    ) -> list[SosEvent]:
        """Most urgent first, then most recently raised.

        There is no free-text search: an SOS queue is read in full, and a
        commander who filters one out is choosing not to see a responder in
        trouble. Priority and status are the only narrowing offered.
        """
        stmt = (
            self._filtered(priority=priority, status=status)
            .order_by(SosEvent.priority.asc(), SosEvent.raised_at.desc())
            .limit(limit)
            .offset(offset)
        )
        return list(self.session.scalars(stmt))

    def count(
        self,
        *,
        priority: SosPriority | None = None,
        status: SosStatus | None = None,
    ) -> int:
        stmt = self._filtered(priority=priority, status=status).with_only_columns(
            func.count(SosEvent.id)
        )
        return self.session.scalar(stmt) or 0

    def count_by_priority(self) -> dict[SosPriority, int]:
        """Totals for every priority, including the ones with no calls."""
        stmt = select(SosEvent.priority, func.count(SosEvent.id)).group_by(SosEvent.priority)
        counted = dict.fromkeys(SosPriority, 0)
        for priority, total in self.session.execute(stmt):
            counted[SosPriority(priority)] = total
        return counted

    def count_by_status(self) -> dict[SosStatus, int]:
        stmt = select(SosEvent.status, func.count(SosEvent.id)).group_by(SosEvent.status)
        counted = dict.fromkeys(SosStatus, 0)
        for status, total in self.session.execute(stmt):
            counted[SosStatus(status)] = total
        return counted

    def _filtered(
        self,
        *,
        priority: SosPriority | None,
        status: SosStatus | None,
    ):
        stmt = select(SosEvent)
        if priority is not None:
            stmt = stmt.where(SosEvent.priority == priority)
        if status is not None:
            stmt = stmt.where(SosEvent.status == status)
        return stmt
