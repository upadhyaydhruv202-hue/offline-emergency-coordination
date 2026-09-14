"""Wire representations of :class:`~app.models.hazard.Hazard`.

``observed_at`` is required rather than defaulted to the time of receipt. The
backend cannot know when a responder saw a hazard, and substituting its own
clock would silently fabricate that - a report that says a bridge was unsafe
"now" when it was seen six hours ago is worse than a rejected upload.
"""

from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.models.enums import HazardSeverity, HazardStatus, HazardType


class HazardBase(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    incident_id: uuid.UUID | None = None
    type: HazardType
    severity: HazardSeverity
    description: str | None = Field(default=None, max_length=2000)
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    status: HazardStatus = HazardStatus.REPORTED


class HazardCreate(HazardBase):
    """An upload of a hazard reported on a device.

    ``id`` and ``hazard_code`` are minted on the handset, which has already
    shown the report to a responder and may have broadcast the code.
    """

    id: uuid.UUID
    hazard_code: str = Field(min_length=1, max_length=32)
    reported_by: str = Field(min_length=1, max_length=64)
    observed_at: datetime
    created_at: datetime | None = None


class HazardUpdate(BaseModel):
    """A partial update. Omitted fields are left as they are."""

    model_config = ConfigDict(str_strip_whitespace=True)

    incident_id: uuid.UUID | None = None
    type: HazardType | None = None
    severity: HazardSeverity | None = None
    description: str | None = Field(default=None, max_length=2000)
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    observed_at: datetime | None = None
    status: HazardStatus | None = None


class HazardRead(HazardBase):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    hazard_code: str
    reported_by: str
    priority: int
    observed_at: datetime
    created_at: datetime
    updated_at: datetime


class HazardSeverityCounts(BaseModel):
    """Counts per severity, always with all four keys present."""

    critical: int = 0
    high: int = 0
    medium: int = 0
    low: int = 0


class HazardStatusCounts(BaseModel):
    """Counts per status, always with all three keys present."""

    reported: int = 0
    verified: int = 0
    resolved: int = 0


class HazardBoard(BaseModel):
    """The command-centre summary above the hazard list."""

    total: int = 0
    by_severity: HazardSeverityCounts = HazardSeverityCounts()
    by_status: HazardStatusCounts = HazardStatusCounts()


class HazardPage(BaseModel):
    items: list[HazardRead]
    total: int
