"""Wire representations of :class:`~app.models.sos_event.SosEvent`.

``raised_at`` is required and is deliberately not called ``timestamp``: see
the module docstring of :mod:`app.models.sos_event`. It is never defaulted to
the time of receipt, because how long a responder has been waiting is the
single most important thing about an SOS and the backend cannot infer it.
"""

from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.models.enums import SosPriority, SosStatus


class SosEventBase(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    incident_id: uuid.UUID | None = None
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    priority: SosPriority
    message: str | None = Field(default=None, max_length=2000)
    status: SosStatus = SosStatus.CREATED


class SosEventCreate(SosEventBase):
    """An upload of an SOS raised on a device.

    ``id`` and ``sos_code`` are minted on the handset so the call can be
    referred to by code over the radio before this peer has ever seen it.
    """

    id: uuid.UUID
    sos_code: str = Field(min_length=1, max_length=32)
    created_by: str = Field(min_length=1, max_length=64)
    raised_at: datetime
    created_at: datetime | None = None


class SosEventUpdate(BaseModel):
    """A partial update. Omitted fields are left as they are."""

    model_config = ConfigDict(str_strip_whitespace=True)

    incident_id: uuid.UUID | None = None
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    priority: SosPriority | None = None
    message: str | None = Field(default=None, max_length=2000)
    raised_at: datetime | None = None
    status: SosStatus | None = None


class SosEventRead(SosEventBase):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    sos_code: str
    created_by: str
    raised_at: datetime
    created_at: datetime
    updated_at: datetime


class SosPriorityCounts(BaseModel):
    """Counts per priority, always with all three keys present."""

    critical: int = 0
    high: int = 0
    medium: int = 0


class SosStatusCounts(BaseModel):
    """Counts per status, always with all three keys present."""

    created: int = 0
    acknowledged: int = 0
    resolved: int = 0


class SosBoard(BaseModel):
    """The command-centre summary above the SOS queue."""

    total: int = 0
    by_priority: SosPriorityCounts = SosPriorityCounts()
    by_status: SosStatusCounts = SosStatusCounts()


class SosEventPage(BaseModel):
    items: list[SosEventRead]
    total: int
