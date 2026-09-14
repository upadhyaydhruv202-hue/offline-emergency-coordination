from __future__ import annotations

from fastapi import APIRouter

from app.api.deps import CurrentUser, DbSession
from app.schemas.command import CommandSnapshot
from app.services.command_service import CommandService

router = APIRouter(prefix="/command", tags=["Command centre"])


@router.get("/snapshot", response_model=CommandSnapshot)
def command_snapshot(session: DbSession, _: CurrentUser) -> CommandSnapshot:
    return CommandService(session).snapshot()
