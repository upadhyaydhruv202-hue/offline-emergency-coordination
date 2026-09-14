from __future__ import annotations

import uuid

from sqlalchemy.orm import Session

from app.core.errors import NotFoundError
from app.models.enums import FacilityKind, FacilityStatus
from app.models.facility import Facility
from app.repositories.facility_repository import FacilityRepository
from app.repositories.incident_repository import IncidentRepository
from app.schemas.facility import (
    FacilityBoard,
    FacilityCreate,
    FacilityPage,
    FacilityRead,
    FacilityUpdate,
)


class FacilityService:
    def __init__(self, session: Session) -> None:
        self.session = session
        self.facilities = FacilityRepository(session)
        self.incidents = IncidentRepository(session)

    def register(self, payload: FacilityCreate) -> Facility:
        existing = self.facilities.get(payload.id)
        if existing is not None:
            return self._apply(existing, payload)

        if payload.incident_id is not None and self.incidents.get(payload.incident_id) is None:
            raise NotFoundError("No incident with that identifier")

        row = Facility(
            id=payload.id,
            facility_code=payload.facility_code,
            kind=payload.kind,
            name=payload.name,
            status=payload.status,
            incident_id=payload.incident_id,
            latitude=payload.latitude,
            longitude=payload.longitude,
            capacity_total=payload.capacity_total,
            occupancy=payload.occupancy,
            emergency_available=payload.emergency_available,
            notes=payload.notes,
        )
        created = self.facilities.add(row)
        self.session.commit()
        self.session.refresh(created)
        return created

    def update(self, facility_id: uuid.UUID, payload: FacilityUpdate) -> Facility:
        return self._apply(self.get(facility_id), payload)

    def get(self, facility_id: uuid.UUID) -> Facility:
        row = self.facilities.get(facility_id)
        if row is None:
            raise NotFoundError("No facility with that identifier")
        return row

    def page(
        self,
        *,
        kind: FacilityKind | None = None,
        status: FacilityStatus | None = None,
        limit: int = 100,
        offset: int = 0,
    ) -> FacilityPage:
        items = self.facilities.search(kind=kind, status=status, limit=limit, offset=offset)
        return FacilityPage(
            items=[FacilityRead.model_validate(row) for row in items],
            total=self.facilities.count(kind=kind, status=status),
            board=self.board(),
        )

    def board(self) -> FacilityBoard:
        return FacilityBoard(
            hospitals=self.facilities.count(kind=FacilityKind.HOSPITAL),
            shelters=self.facilities.count(kind=FacilityKind.SHELTER),
            resource_caches=self.facilities.count(kind=FacilityKind.RESOURCE_CACHE),
            hospital_beds_remaining=self.facilities.remaining_capacity(FacilityKind.HOSPITAL),
            shelter_spaces_remaining=self.facilities.remaining_capacity(FacilityKind.SHELTER),
        )

    def _apply(self, row: Facility, payload: FacilityCreate | FacilityUpdate) -> Facility:
        changed = payload.model_fields_set - {"id", "facility_code", "kind"}
        if "incident_id" in changed and payload.incident_id is not None:
            if self.incidents.get(payload.incident_id) is None:
                raise NotFoundError("No incident with that identifier")
        for field in changed:
            setattr(row, field, getattr(payload, field))
        self.session.add(row)
        self.session.commit()
        self.session.refresh(row)
        return row
