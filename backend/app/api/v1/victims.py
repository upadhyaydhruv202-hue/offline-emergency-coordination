"""Victim endpoints.

These serve the command centre and receive uploads from handsets. They are
not on the critical path for a responder: a device registers casualties into
its own SQLite and stays useful with this API unreachable.
"""

from __future__ import annotations

import uuid
from typing import Annotated

from fastapi import APIRouter, Query, status

from app.api.deps import CurrentUser, VictimServiceDep
from app.models.enums import TriageCategory, VictimStatus
from app.schemas.victim import VictimBoard, VictimCreate, VictimPage, VictimRead, VictimUpdate

router = APIRouter(prefix="/victims", tags=["Victims"])


@router.get("", response_model=VictimPage, summary="List victims, most urgent first")
def list_victims(
    victim_service: VictimServiceDep,
    _: CurrentUser,
    search: Annotated[str | None, Query(max_length=160)] = None,
    triage: TriageCategory | None = None,
    victim_status: Annotated[VictimStatus | None, Query(alias="status")] = None,
    limit: Annotated[int, Query(ge=1, le=500)] = 100,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> VictimPage:
    return victim_service.page(
        search=search,
        triage=triage,
        status=victim_status,
        limit=limit,
        offset=offset,
    )


@router.get("/board", response_model=VictimBoard, summary="Counts by triage category")
def victim_board(victim_service: VictimServiceDep, _: CurrentUser) -> VictimBoard:
    return victim_service.board()


@router.get("/{victim_id}", response_model=VictimRead, summary="One victim record")
def read_victim(
    victim_id: uuid.UUID, victim_service: VictimServiceDep, _: CurrentUser
) -> VictimRead:
    return VictimRead.model_validate(victim_service.get(victim_id))


@router.post(
    "",
    response_model=VictimRead,
    status_code=status.HTTP_201_CREATED,
    summary="Upload a victim registered on a device",
)
def create_victim(
    payload: VictimCreate, victim_service: VictimServiceDep, _: CurrentUser
) -> VictimRead:
    return VictimRead.model_validate(victim_service.register(payload))


@router.patch("/{victim_id}", response_model=VictimRead, summary="Reassess or update a victim")
def update_victim(
    victim_id: uuid.UUID,
    payload: VictimUpdate,
    victim_service: VictimServiceDep,
    _: CurrentUser,
) -> VictimRead:
    return VictimRead.model_validate(victim_service.update(victim_id, payload))
