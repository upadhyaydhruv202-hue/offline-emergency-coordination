"""Health probe contracts."""

from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel

HealthState = Literal["ok", "degraded", "unavailable"]


class HealthResponse(BaseModel):
    status: HealthState
    service: str
    version: str
    environment: str
    timestamp: datetime


class DatabaseHealthResponse(HealthResponse):
    database: HealthState
    dialect: str
    detail: str | None = None
