"""Health/readiness checks."""

from __future__ import annotations

from datetime import UTC, datetime

from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.core.config import settings
from app.schemas.health import DatabaseHealthResponse, HealthResponse


def liveness() -> HealthResponse:
    """Answers 'is the process up?' - deliberately free of dependencies."""
    return HealthResponse(
        status="ok",
        service=settings.app_name,
        version=settings.app_version,
        environment=settings.environment,
        timestamp=datetime.now(UTC),
    )


def readiness(session: Session) -> DatabaseHealthResponse:
    """Answers 'can this instance serve traffic?' by touching the database."""
    base = liveness()
    try:
        session.execute(text("SELECT 1"))
    except SQLAlchemyError as exc:
        return DatabaseHealthResponse(
            **base.model_dump() | {"status": "degraded"},
            database="unavailable",
            dialect=session.bind.dialect.name if session.bind else "unknown",
            detail=type(exc).__name__,
        )

    return DatabaseHealthResponse(
        **base.model_dump(),
        database="ok",
        dialect=session.bind.dialect.name if session.bind else "unknown",
    )
