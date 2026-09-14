"""Responder roster endpoint.

Read-only: accounts are created through ``/auth``, and a roster the command
centre could edit would put two authorities on the same row.
"""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Query

from app.api.deps import CurrentUser, ResponderServiceDep
from app.models.enums import UserRole
from app.schemas.responder import ResponderPage

router = APIRouter(prefix="/responders", tags=["Responders"])


@router.get("", response_model=ResponderPage, summary="List responders, by name")
def list_responders(
    responder_service: ResponderServiceDep,
    _: CurrentUser,
    search: Annotated[str | None, Query(max_length=200)] = None,
    role: UserRole | None = None,
    is_active: bool | None = None,
    limit: Annotated[int, Query(ge=1, le=500)] = 100,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> ResponderPage:
    return responder_service.page(
        search=search,
        role=role,
        is_active=is_active,
        limit=limit,
        offset=offset,
    )
