"""Database access for :class:`~app.models.victim.Victim`."""

from __future__ import annotations

from sqlalchemy import func, or_, select

from app.models.enums import TriageCategory, VictimStatus
from app.models.victim import Victim
from app.repositories.base import BaseRepository


class VictimRepository(BaseRepository[Victim]):
    model = Victim

    def get_by_temporary_id(self, temporary_id: str) -> Victim | None:
        stmt = select(Victim).where(Victim.temporary_id == temporary_id.strip())
        return self.session.scalars(stmt).first()

    def search(
        self,
        *,
        search: str | None = None,
        triage: TriageCategory | None = None,
        status: VictimStatus | None = None,
        limit: int = 100,
        offset: int = 0,
    ) -> list[Victim]:
        """Most urgent first, then most recently touched.

        Ordering lives here rather than in the caller because the composite
        index on ``(priority, updated_at)`` only helps if the query matches it.
        """
        stmt = (
            self._filtered(search=search, triage=triage, status=status)
            .order_by(Victim.priority.asc(), Victim.updated_at.desc())
            .limit(limit)
            .offset(offset)
        )
        return list(self.session.scalars(stmt))

    def count(
        self,
        *,
        search: str | None = None,
        triage: TriageCategory | None = None,
        status: VictimStatus | None = None,
    ) -> int:
        stmt = self._filtered(search=search, triage=triage, status=status).with_only_columns(
            func.count(Victim.id)
        )
        return self.session.scalar(stmt) or 0

    def count_by_triage(self) -> dict[TriageCategory, int]:
        """Totals for every category, including the ones with no casualties."""
        stmt = select(Victim.triage_category, func.count(Victim.id)).group_by(
            Victim.triage_category
        )
        counted = dict.fromkeys(TriageCategory, 0)
        for category, total in self.session.execute(stmt):
            counted[TriageCategory(category)] = total
        return counted

    def count_by_status(self) -> dict[VictimStatus, int]:
        stmt = select(Victim.status, func.count(Victim.id)).group_by(Victim.status)
        counted = dict.fromkeys(VictimStatus, 0)
        for status, total in self.session.execute(stmt):
            counted[VictimStatus(status)] = total
        return counted

    def _filtered(
        self,
        *,
        search: str | None,
        triage: TriageCategory | None,
        status: VictimStatus | None,
    ):
        stmt = select(Victim)
        if triage is not None:
            stmt = stmt.where(Victim.triage_category == triage)
        if status is not None:
            stmt = stmt.where(Victim.status == status)

        term = (search or "").strip()
        if term:
            # Matches what a radio operator would have to hand: a name, the tag
            # number, or the injury they were told about.
            pattern = f"%{term.lower()}%"
            stmt = stmt.where(
                or_(
                    func.lower(Victim.name).like(pattern),
                    func.lower(Victim.temporary_id).like(pattern),
                    func.lower(Victim.injury_type).like(pattern),
                )
            )
        return stmt
