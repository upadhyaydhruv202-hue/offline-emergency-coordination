"""Responder roster endpoint.

Read-only for identity. Presence (status + last known position) is a separate
row so the roster account and the last ingested check-in do not fight.
"""

from __future__ import annotations

import uuid
from typing import Annotated

from fastapi import APIRouter, Query

from app.api.deps import CurrentUser, DbSession, ResponderServiceDep
from app.core.errors import AuthorizationError
from app.models.enums import COMMAND_ROLES
from app.models.enums import UserRole
from app.schemas.presence import PresenceRead, PresenceUpdate
from app.schemas.responder import ResponderPage
from app.services.presence_service import PresenceService

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


@router.patch("/{responder_id}/presence", response_model=PresenceRead)
def update_presence(
    responder_id: uuid.UUID,
    payload: PresenceUpdate,
    session: DbSession,
    current: CurrentUser,
) -> PresenceRead:
    if current.id != responder_id and current.role not in COMMAND_ROLES:
        raise AuthorizationError("You may only update your own responder status")
    return PresenceRead.model_validate(PresenceService(session).upsert(responder_id, payload))
