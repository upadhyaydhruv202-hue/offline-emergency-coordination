"""Wire representations of :class:`~app.models.victim.Victim`.

Field names are snake_case here and camelCase on the handset; the mobile
client maps between them. Every optional field really is optional - a
responder must be able to save a record having decided nothing but the triage
category.
"""

from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.models.enums import AgeGroup, Gender, TriageCategory, VictimStatus


class VictimBase(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    name: str | None = Field(default=None, max_length=160)
    age: int | None = Field(default=None, ge=0, le=130)
    age_group: AgeGroup = AgeGroup.UNKNOWN
    gender: Gender = Gender.UNKNOWN
    medical_condition: str | None = Field(default=None, max_length=2000)
    injury_type: str | None = Field(default=None, max_length=200)
    triage_category: TriageCategory
    assistance_required: str | None = Field(default=None, max_length=2000)
    status: VictimStatus = VictimStatus.REGISTERED
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)


class VictimCreate(VictimBase):
    """An upload of a record that already exists on a device.

    ``id`` and ``temporary_id`` are supplied by the client because the record
    was created offline and is already known by those identifiers on the radio
    and on the triage tag. Re-keying it here would break that.
    """

    id: uuid.UUID
    temporary_id: str = Field(min_length=1, max_length=32)
    created_by: str = Field(min_length=1, max_length=64)
    created_at: datetime | None = None


class VictimUpdate(BaseModel):
    """A partial update. Omitted fields are left as they are."""

    model_config = ConfigDict(str_strip_whitespace=True)

    name: str | None = Field(default=None, max_length=160)
    age: int | None = Field(default=None, ge=0, le=130)
    age_group: AgeGroup | None = None
    gender: Gender | None = None
    medical_condition: str | None = Field(default=None, max_length=2000)
    injury_type: str | None = Field(default=None, max_length=200)
    triage_category: TriageCategory | None = None
    assistance_required: str | None = Field(default=None, max_length=2000)
    status: VictimStatus | None = None
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)


class VictimRead(VictimBase):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    temporary_id: str
    priority: int
    created_by: str
    created_at: datetime
    updated_at: datetime


class TriageCounts(BaseModel):
    """Counts per triage category, always with all four keys present.

    A dashboard that hides a category when it is empty makes an empty
    CRITICAL column indistinguishable from a broken query.
    """

    critical: int = 0
    urgent: int = 0
    moderate: int = 0
    stable: int = 0


class VictimBoard(BaseModel):
    """The command-centre summary above the victim table."""

    total: int = 0
    open_cases: int = 0
    evacuated: int = 0
    by_triage: TriageCounts = TriageCounts()


class VictimPage(BaseModel):
    """A page of victims plus the counts for the whole, unfiltered set."""

    items: list[VictimRead]
    board: VictimBoard
    total: int
