from __future__ import annotations

import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Query, status

from app.api.deps import CurrentUser, DbSession, require_roles
from app.models.enums import COMMAND_ROLES, FacilityKind, FacilityStatus
from app.models.user import User
from app.schemas.facility import FacilityCreate, FacilityPage, FacilityRead, FacilityUpdate
from app.services.facility_service import FacilityService

router = APIRouter(prefix="/facilities", tags=["Facilities"])


def get_facility_service(session: DbSession) -> FacilityService:
    return FacilityService(session)


FacilityServiceDep = Annotated[FacilityService, Depends(get_facility_service)]
CommandUser = Annotated[User, Depends(require_roles(*COMMAND_ROLES))]


@router.get("", response_model=FacilityPage)
def list_facilities(
    facility_service: FacilityServiceDep,
    _: CurrentUser,
    kind: FacilityKind | None = None,
    facility_status: Annotated[FacilityStatus | None, Query(alias="status")] = None,
    limit: Annotated[int, Query(ge=1, le=500)] = 100,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> FacilityPage:
    return facility_service.page(kind=kind, status=facility_status, limit=limit, offset=offset)


@router.get("/{facility_id}", response_model=FacilityRead)
def read_facility(
    facility_id: uuid.UUID, facility_service: FacilityServiceDep, _: CurrentUser
) -> FacilityRead:
    return FacilityRead.model_validate(facility_service.get(facility_id))


@router.post("", response_model=FacilityRead, status_code=status.HTTP_201_CREATED)
def create_facility(
    payload: FacilityCreate, facility_service: FacilityServiceDep, _: CommandUser
) -> FacilityRead:
    return FacilityRead.model_validate(facility_service.register(payload))


@router.patch("/{facility_id}", response_model=FacilityRead)
def update_facility(
    facility_id: uuid.UUID,
    payload: FacilityUpdate,
    facility_service: FacilityServiceDep,
    _: CommandUser,
) -> FacilityRead:
    return FacilityRead.model_validate(facility_service.update(facility_id, payload))
