"""Hospitals, shelters and staging caches for the command-centre COP.

These are coordination-peer records, not field-device journals. Occupancy is
whatever was last reported — not a live bed-management system.
"""

from __future__ import annotations

import uuid

from sqlalchemy import Boolean, Enum, Float, ForeignKey, Integer, String, Text, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin, UuidPrimaryKeyMixin
from app.models.enums import FacilityKind, FacilityStatus


def _enum(enum_cls: type, name: str) -> Enum:
    return Enum(
        enum_cls,
        name=name,
        values_callable=lambda cls: [member.value for member in cls],
        native_enum=False,
        length=32,
    )


class Facility(UuidPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "facilities"

    facility_code: Mapped[str] = mapped_column(String(32), unique=True, index=True, nullable=False)
    kind: Mapped[FacilityKind] = mapped_column(_enum(FacilityKind, "facility_kind"), nullable=False)
    name: Mapped[str] = mapped_column(String(160), nullable=False)
    status: Mapped[FacilityStatus] = mapped_column(
        _enum(FacilityStatus, "facility_status"), nullable=False, default=FacilityStatus.OPEN
    )
    incident_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("incidents.id", ondelete="SET NULL"), nullable=True
    )
    latitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    longitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    capacity_total: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    occupancy: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    emergency_available: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    @property
    def remaining(self) -> int:
        return max(self.capacity_total - self.occupancy, 0)

    def __repr__(self) -> str:  # pragma: no cover
        return f"<Facility {self.facility_code} {self.kind.value}>"
