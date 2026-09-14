"""SOS endpoints.

These serve the command centre and receive uploads from handsets. The route
prefix is ``/sos`` rather than ``/sos-events`` because that is what it is
called on the radio and in the UI; the table is ``sos_events``.
"""

from __future__ import annotations

import uuid
from typing import Annotated

from fastapi import APIRouter, Query, status

from app.api.deps import CurrentUser, SosServiceDep
from app.models.enums import SosPriority, SosStatus
from app.schemas.sos_event import (
    SosBoard,
    SosEventCreate,
    SosEventPage,
    SosEventRead,
    SosEventUpdate,
)

router = APIRouter(prefix="/sos", tags=["SOS"])


@router.get("", response_model=SosEventPage, summary="List SOS events, most urgent first")
def list_sos_events(
    sos_service: SosServiceDep,
    _: CurrentUser,
    priority: SosPriority | None = None,
    sos_status: Annotated[SosStatus | None, Query(alias="status")] = None,
    limit: Annotated[int, Query(ge=1, le=500)] = 100,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> SosEventPage:
    return sos_service.page(
        priority=priority,
        status=sos_status,
        limit=limit,
        offset=offset,
    )


@router.get("/board", response_model=SosBoard, summary="Counts by priority and status")
def sos_board(sos_service: SosServiceDep, _: CurrentUser) -> SosBoard:
    return sos_service.board()


@router.get("/{sos_event_id}", response_model=SosEventRead, summary="One SOS event")
def read_sos_event(
    sos_event_id: uuid.UUID, sos_service: SosServiceDep, _: CurrentUser
) -> SosEventRead:
    return SosEventRead.model_validate(sos_service.get(sos_event_id))


@router.post(
    "",
    response_model=SosEventRead,
    status_code=status.HTTP_201_CREATED,
    summary="Upload an SOS raised on a device",
)
def create_sos_event(
    payload: SosEventCreate, sos_service: SosServiceDep, _: CurrentUser
) -> SosEventRead:
    return SosEventRead.model_validate(sos_service.register(payload))


@router.patch(
    "/{sos_event_id}", response_model=SosEventRead, summary="Acknowledge or resolve an SOS"
)
def update_sos_event(
    sos_event_id: uuid.UUID,
    payload: SosEventUpdate,
    sos_service: SosServiceDep,
    _: CurrentUser,
) -> SosEventRead:
    return SosEventRead.model_validate(sos_service.update(sos_event_id, payload))
