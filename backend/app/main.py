"""FastAPI application factory and entrypoint."""

from __future__ import annotations

import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1 import api_router_v1, auth, health
from app.core.config import settings
from app.core.errors import register_exception_handlers
from app.core.logging import configure_logging

logger = logging.getLogger(__name__)

DESCRIPTION = """
Coordination backend for the Offline-First Disaster Response Platform.

The backend is a **synchronisation and command-centre peer**, not the
operational dependency of a field device. Mobile clients read and write their
own local database first and reconcile with this service when a link exists.
"""


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    configure_logging()
    logger.info(
        "Starting %s v%s (environment=%s)",
        settings.app_name,
        settings.app_version,
        settings.environment,
    )
    yield
    logger.info("Shutting down %s", settings.app_name)


def create_app() -> FastAPI:
    app = FastAPI(
        title=settings.app_name,
        version=settings.app_version,
        description=DESCRIPTION,
        docs_url="/docs",
        redoc_url="/redoc",
        openapi_url="/openapi.json",
        lifespan=lifespan,
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origin_list,
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type"],
    )

    register_exception_handlers(app)

    app.include_router(api_router_v1, prefix=settings.api_v1_prefix)

    # Unversioned aliases: `/health` for container probes and `/auth/login` for
    # the paths named in the Slice 1 specification. Hidden from the schema so
    # `/api/v1/...` stays the one documented surface.
    app.include_router(health.router, include_in_schema=False)
    app.include_router(auth.router, include_in_schema=False)

    @app.get("/", include_in_schema=False)
    def service_info() -> dict[str, str]:
        return {
            "service": settings.app_name,
            "version": settings.app_version,
            "docs": "/docs",
            "health": "/health",
            "api": settings.api_v1_prefix,
        }

    return app


app = create_app()
