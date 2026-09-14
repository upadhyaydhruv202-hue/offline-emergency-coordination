"""Wire representations of :class:`~app.models.incident.Incident`.

Field names are snake_case here and camelCase on the handset; the mobile
client maps between them.
"""

from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.models.enums import DisasterType, IncidentStatus


class IncidentBase(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    title: str = Field(min_length=1, max_length=200)
    disaster_type: DisasterType
    description: str | None = Field(default=None, max_length=2000)
    status: IncidentStatus = IncidentStatus.ACTIVE
    assigned_zone: str | None = Field(default=None, max_length=120)
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)


class IncidentCreate(IncidentBase):
    """An upload of an incident that was declared on a device.

    ``id`` and ``incident_code`` are supplied by the client: the incident is
    already being named by that code on the radio, and re-keying it here would
    desynchronise the paper record from the digital one.
    """

    id: uuid.UUID
    incident_code: str = Field(min_length=1, max_length=32)
    created_by: str = Field(min_length=1, max_length=64)
    last_modified_by: str | None = Field(default=None, max_length=64)
    created_at: datetime | None = None


class IncidentUpdate(BaseModel):
    """A partial update. Omitted fields are left as they are."""

    model_config = ConfigDict(str_strip_whitespace=True)

    title: str | None = Field(default=None, min_length=1, max_length=200)
    disaster_type: DisasterType | None = None
    description: str | None = Field(default=None, max_length=2000)
    status: IncidentStatus | None = None
    assigned_zone: str | None = Field(default=None, max_length=120)
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    last_modified_by: str | None = Field(default=None, max_length=64)


class IncidentRead(IncidentBase):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    incident_code: str
    created_by: str
    last_modified_by: str | None = None
    created_at: datetime
    updated_at: datetime


class IncidentStatusCounts(BaseModel):
    """Counts per status, always with all three keys present.

    Same reasoning as :class:`~app.schemas.victim.TriageCounts`: a key that
    disappears when its count is zero makes an empty column and a broken
    query look identical.
    """

    active: int = 0
    paused: int = 0
    resolved: int = 0


class IncidentBoard(BaseModel):
    """The command-centre summary above the incident list."""

    total: int = 0
    by_status: IncidentStatusCounts = IncidentStatusCounts()


class IncidentPage(BaseModel):
    items: list[IncidentRead]
    total: int
