"""Liveness and readiness probes."""

from __future__ import annotations

from fastapi import APIRouter

from app.api.deps import DbSession
from app.schemas.health import DatabaseHealthResponse, HealthResponse
from app.services import health_service

router = APIRouter(tags=["Health"])


@router.get("/health", response_model=HealthResponse, summary="Liveness probe")
def health() -> HealthResponse:
    return health_service.liveness()


@router.get(
    "/health/ready",
    response_model=DatabaseHealthResponse,
    summary="Readiness probe (includes database)",
)
def health_ready(session: DbSession) -> DatabaseHealthResponse:
    return health_service.readiness(session)
