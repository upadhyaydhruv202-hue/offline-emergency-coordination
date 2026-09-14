"""Something a responder saw that makes an area dangerous to approach.

The mobile field is named ``timestamp``; on the wire and in this table it is
``observed_at``, because ``timestamp`` sitting next to ``created_at`` reads as
a synonym for it while meaning the opposite end of the journey:
``observed_at`` is when a responder saw the hazard, ``created_at`` is when this
peer first stored the report.

Like every field-operations table this is a destination for records minted on
a device, so the primary key arrives with the upload.
"""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, Float, ForeignKey, Index, Integer, String, Text, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin, UuidPrimaryKeyMixin
from app.models.enums import HazardSeverity, HazardStatus, HazardType


def _enum(enum_cls: type, name: str) -> Enum:
    return Enum(
        enum_cls,
        name=name,
        values_callable=lambda cls: [member.value for member in cls],
    )


class Hazard(UuidPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "hazards"

    hazard_code: Mapped[str] = mapped_column(String(32), unique=True, index=True, nullable=False)

    # Nullable and ``SET NULL`` on delete: a blocked road stays a blocked road
    # after the incident that prompted the report is closed.
    incident_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("incidents.id", ondelete="SET NULL"), nullable=True
    )

    reported_by: Mapped[str] = mapped_column(String(64), nullable=False)

    type: Mapped[HazardType] = mapped_column(_enum(HazardType, "hazard_type"), nullable=False)
    severity: Mapped[HazardSeverity] = mapped_column(
        _enum(HazardSeverity, "hazard_severity"), nullable=False
    )

    # Denormalised :attr:`HazardSeverity.priority`, for the same reason as
    # ``victims.priority``: ordering by severity becomes an indexed sort
    # instead of a CASE expression. It also makes the order dialect-independent
    # - CRITICAL/HIGH/MEDIUM/LOW does not sort correctly as a plain label.
    priority: Mapped[int] = mapped_column(Integer, nullable=False)

    description: Mapped[str | None] = mapped_column(Text, nullable=True)

    latitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    longitude: Mapped[float | None] = mapped_column(Float, nullable=True)

    observed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)

    status: Mapped[HazardStatus] = mapped_column(
        _enum(HazardStatus, "hazard_status"), nullable=False, default=HazardStatus.REPORTED
    )

    __table_args__ = (Index("ix_hazards_priority_observed_at", "priority", "observed_at"),)

    def __repr__(self) -> str:  # pragma: no cover - debugging aid
        return f"<Hazard {self.hazard_code} {self.severity.value}>"
