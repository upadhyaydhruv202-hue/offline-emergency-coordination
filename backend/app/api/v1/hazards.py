"""Hazard endpoints.

These serve the command centre and receive uploads from handsets. They are
not on the critical path for a responder: a device records a hazard into its
own SQLite and stays useful with this API unreachable.
"""

from __future__ import annotations

import uuid
from typing import Annotated

from fastapi import APIRouter, Query, status

from app.api.deps import CurrentUser, HazardServiceDep
from app.models.enums import HazardSeverity, HazardStatus, HazardType
from app.schemas.hazard import HazardBoard, HazardCreate, HazardPage, HazardRead, HazardUpdate

router = APIRouter(prefix="/hazards", tags=["Hazards"])


@router.get("", response_model=HazardPage, summary="List hazards, most severe first")
def list_hazards(
    hazard_service: HazardServiceDep,
    _: CurrentUser,
    search: Annotated[str | None, Query(max_length=200)] = None,
    # Aliased because ``type`` shadows the builtin as a parameter name but is
    # the field name the handset and the command centre both use.
    hazard_type: Annotated[HazardType | None, Query(alias="type")] = None,
    severity: HazardSeverity | None = None,
    hazard_status: Annotated[HazardStatus | None, Query(alias="status")] = None,
    limit: Annotated[int, Query(ge=1, le=500)] = 100,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> HazardPage:
    return hazard_service.page(
        search=search,
        hazard_type=hazard_type,
        severity=severity,
        status=hazard_status,
        limit=limit,
        offset=offset,
    )


@router.get("/board", response_model=HazardBoard, summary="Counts by severity and status")
def hazard_board(hazard_service: HazardServiceDep, _: CurrentUser) -> HazardBoard:
    return hazard_service.board()


@router.get("/{hazard_id}", response_model=HazardRead, summary="One hazard report")
def read_hazard(
    hazard_id: uuid.UUID, hazard_service: HazardServiceDep, _: CurrentUser
) -> HazardRead:
    return HazardRead.model_validate(hazard_service.get(hazard_id))


@router.post(
    "",
    response_model=HazardRead,
    status_code=status.HTTP_201_CREATED,
    summary="Upload a hazard reported on a device",
)
def create_hazard(
    payload: HazardCreate, hazard_service: HazardServiceDep, _: CurrentUser
) -> HazardRead:
    return HazardRead.model_validate(hazard_service.register(payload))


@router.patch("/{hazard_id}", response_model=HazardRead, summary="Verify or update a hazard")
def update_hazard(
    hazard_id: uuid.UUID,
    payload: HazardUpdate,
    hazard_service: HazardServiceDep,
    _: CurrentUser,
) -> HazardRead:
    return HazardRead.model_validate(hazard_service.update(hazard_id, payload))
