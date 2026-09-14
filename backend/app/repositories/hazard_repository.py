"""Database access for :class:`~app.models.hazard.Hazard`."""

from __future__ import annotations

from sqlalchemy import func, or_, select

from app.models.enums import HazardSeverity, HazardStatus, HazardType
from app.models.hazard import Hazard
from app.repositories.base import BaseRepository


class HazardRepository(BaseRepository[Hazard]):
    model = Hazard

    def get_by_code(self, hazard_code: str) -> Hazard | None:
        stmt = select(Hazard).where(Hazard.hazard_code == hazard_code.strip())
        return self.session.scalars(stmt).first()

    def search(
        self,
        *,
        search: str | None = None,
        hazard_type: HazardType | None = None,
        severity: HazardSeverity | None = None,
        status: HazardStatus | None = None,
        limit: int = 100,
        offset: int = 0,
    ) -> list[Hazard]:
        """Most severe first, then most recently observed.

        Ordering lives here rather than in the caller because the composite
        index on ``(priority, observed_at)`` only helps if the query matches
        it, and it sorts on the denormalised integer rather than the severity
        label so the order is the same on PostgreSQL and SQLite.
        """
        stmt = (
            self._filtered(
                search=search, hazard_type=hazard_type, severity=severity, status=status
            )
            .order_by(Hazard.priority.asc(), Hazard.observed_at.desc())
            .limit(limit)
            .offset(offset)
        )
        return list(self.session.scalars(stmt))

    def count(
        self,
        *,
        search: str | None = None,
        hazard_type: HazardType | None = None,
        severity: HazardSeverity | None = None,
        status: HazardStatus | None = None,
    ) -> int:
        stmt = self._filtered(
            search=search, hazard_type=hazard_type, severity=severity, status=status
        ).with_only_columns(func.count(Hazard.id))
        return self.session.scalar(stmt) or 0

    def count_by_severity(self) -> dict[HazardSeverity, int]:
        """Totals for every severity, including the ones with no hazards."""
        stmt = select(Hazard.severity, func.count(Hazard.id)).group_by(Hazard.severity)
        counted = dict.fromkeys(HazardSeverity, 0)
        for severity, total in self.session.execute(stmt):
            counted[HazardSeverity(severity)] = total
        return counted

    def count_by_status(self) -> dict[HazardStatus, int]:
        stmt = select(Hazard.status, func.count(Hazard.id)).group_by(Hazard.status)
        counted = dict.fromkeys(HazardStatus, 0)
        for status, total in self.session.execute(stmt):
            counted[HazardStatus(status)] = total
        return counted

    def _filtered(
        self,
        *,
        search: str | None,
        hazard_type: HazardType | None,
        severity: HazardSeverity | None,
        status: HazardStatus | None,
    ):
        stmt = select(Hazard)
        if hazard_type is not None:
            stmt = stmt.where(Hazard.type == hazard_type)
        if severity is not None:
            stmt = stmt.where(Hazard.severity == severity)
        if status is not None:
            stmt = stmt.where(Hazard.status == status)

        term = (search or "").strip()
        if term:
            # The code it was broadcast under, or the words a responder used
            # to describe what they saw.
            pattern = f"%{term.lower()}%"
            stmt = stmt.where(
                or_(
                    func.lower(Hazard.hazard_code).like(pattern),
                    func.lower(Hazard.description).like(pattern),
                )
            )
        return stmt
