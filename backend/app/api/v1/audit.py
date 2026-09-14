from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Query

from app.api.deps import CurrentUser, DbSession
from app.schemas.audit import AuditEventPage
from app.services.audit_service import AuditService

router = APIRouter(prefix="/audit", tags=["Audit"])


@router.get("/events", response_model=AuditEventPage)
def list_events(
    session: DbSession,
    _: CurrentUser,
    limit: Annotated[int, Query(ge=1, le=200)] = 50,
) -> AuditEventPage:
    return AuditService(session).page(limit=limit)
