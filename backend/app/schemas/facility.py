from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.models.enums import FacilityKind, FacilityStatus


class FacilityBase(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    kind: FacilityKind
    name: str = Field(min_length=1, max_length=160)
    status: FacilityStatus = FacilityStatus.OPEN
    incident_id: uuid.UUID | None = None
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    capacity_total: int = Field(default=0, ge=0)
    occupancy: int = Field(default=0, ge=0)
    emergency_available: bool = False
    notes: str | None = Field(default=None, max_length=2000)


class FacilityCreate(FacilityBase):
    id: uuid.UUID
    facility_code: str = Field(min_length=1, max_length=32)


class FacilityUpdate(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    name: str | None = Field(default=None, max_length=160)
    status: FacilityStatus | None = None
    incident_id: uuid.UUID | None = None
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    capacity_total: int | None = Field(default=None, ge=0)
    occupancy: int | None = Field(default=None, ge=0)
    emergency_available: bool | None = None
    notes: str | None = Field(default=None, max_length=2000)


class FacilityRead(FacilityBase):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    facility_code: str
    remaining: int
    created_at: datetime
    updated_at: datetime


class FacilityBoard(BaseModel):
    hospitals: int = 0
    shelters: int = 0
    resource_caches: int = 0
    hospital_beds_remaining: int = 0
    shelter_spaces_remaining: int = 0


class FacilityPage(BaseModel):
    items: list[FacilityRead]
    total: int
    board: FacilityBoard
