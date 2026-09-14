"""Incident endpoints.

These serve the command centre and receive uploads from handsets. They are
not on the critical path for a responder: a device declares an incident into
its own SQLite and stays useful with this API unreachable.
"""

from __future__ import annotations

import uuid
from typing import Annotated

from fastapi import APIRouter, Query, status

from app.api.deps import CurrentUser, IncidentServiceDep
from app.models.enums import DisasterType, IncidentStatus
from app.schemas.incident import (
    IncidentBoard,
    IncidentCreate,
    IncidentPage,
    IncidentRead,
    IncidentUpdate,
)

router = APIRouter(prefix="/incidents", tags=["Incidents"])


@router.get("", response_model=IncidentPage, summary="List incidents, most recent first")
def list_incidents(
    incident_service: IncidentServiceDep,
    _: CurrentUser,
    search: Annotated[str | None, Query(max_length=200)] = None,
    disaster_type: DisasterType | None = None,
    incident_status: Annotated[IncidentStatus | None, Query(alias="status")] = None,
    limit: Annotated[int, Query(ge=1, le=500)] = 100,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> IncidentPage:
    return incident_service.page(
        search=search,
        disaster_type=disaster_type,
        status=incident_status,
        limit=limit,
        offset=offset,
    )


@router.get("/board", response_model=IncidentBoard, summary="Counts by incident status")
def incident_board(incident_service: IncidentServiceDep, _: CurrentUser) -> IncidentBoard:
    return incident_service.board()


@router.get("/{incident_id}", response_model=IncidentRead, summary="One incident")
def read_incident(
    incident_id: uuid.UUID, incident_service: IncidentServiceDep, _: CurrentUser
) -> IncidentRead:
    return IncidentRead.model_validate(incident_service.get(incident_id))


@router.post(
    "",
    response_model=IncidentRead,
    status_code=status.HTTP_201_CREATED,
    summary="Upload an incident declared on a device",
)
def create_incident(
    payload: IncidentCreate, incident_service: IncidentServiceDep, _: CurrentUser
) -> IncidentRead:
    return IncidentRead.model_validate(incident_service.register(payload))


@router.patch("/{incident_id}", response_model=IncidentRead, summary="Update an incident")
def update_incident(
    incident_id: uuid.UUID,
    payload: IncidentUpdate,
    incident_service: IncidentServiceDep,
    _: CurrentUser,
) -> IncidentRead:
    return IncidentRead.model_validate(incident_service.update(incident_id, payload))
