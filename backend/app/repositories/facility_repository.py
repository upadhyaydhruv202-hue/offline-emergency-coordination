from __future__ import annotations

from sqlalchemy import func, select

from app.models.enums import FacilityKind, FacilityStatus
from app.models.facility import Facility
from app.repositories.base import BaseRepository


class FacilityRepository(BaseRepository[Facility]):
    model = Facility

    def get_by_code(self, facility_code: str) -> Facility | None:
        stmt = select(Facility).where(Facility.facility_code == facility_code.strip())
        return self.session.scalars(stmt).first()

    def search(
        self,
        *,
        kind: FacilityKind | None = None,
        status: FacilityStatus | None = None,
        limit: int = 100,
        offset: int = 0,
    ) -> list[Facility]:
        stmt = self._filtered(kind=kind, status=status).order_by(Facility.name).limit(limit).offset(offset)
        return list(self.session.scalars(stmt))

    def count(self, *, kind: FacilityKind | None = None, status: FacilityStatus | None = None) -> int:
        stmt = self._filtered(kind=kind, status=status).with_only_columns(func.count(Facility.id))
        return self.session.scalar(stmt) or 0

    def remaining_capacity(self, kind: FacilityKind) -> int:
        rows = self.session.scalars(select(Facility).where(Facility.kind == kind)).all()
        return sum(row.remaining for row in rows)

    def _filtered(self, *, kind: FacilityKind | None, status: FacilityStatus | None):
        stmt = select(Facility)
        if kind is not None:
            stmt = stmt.where(Facility.kind == kind)
        if status is not None:
            stmt = stmt.where(Facility.status == status)
        return stmt
