"""A responder's own distress call.

The mobile field is named ``timestamp``; on the wire and in this table it is
``raised_at``. ``timestamp`` next to ``created_at`` reads as a synonym for it,
and the two mean very different things here: ``raised_at`` is when a responder
pressed the button, ``created_at`` is when this peer first stored the record -
hours later if the handset was out of coverage.

Like every field-operations table this is a destination for records minted on
a device, so the primary key arrives with the upload.
"""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, Float, ForeignKey, Index, String, Text, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin, UuidPrimaryKeyMixin
from app.models.enums import SosPriority, SosStatus


def _enum(enum_cls: type, name: str) -> Enum:
    return Enum(
        enum_cls,
        name=name,
        values_callable=lambda cls: [member.value for member in cls],
    )


class SosEvent(UuidPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "sos_events"

    sos_code: Mapped[str] = mapped_column(String(32), unique=True, index=True, nullable=False)

    # Nullable and ``SET NULL`` on delete: a responder in trouble is never
    # discarded because the incident they were working was closed or removed.
    incident_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("incidents.id", ondelete="SET NULL"), nullable=True
    )

    created_by: Mapped[str] = mapped_column(String(64), nullable=False)

    latitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    longitude: Mapped[float | None] = mapped_column(Float, nullable=True)

    raised_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)

    priority: Mapped[SosPriority] = mapped_column(
        _enum(SosPriority, "sos_priority"), nullable=False
    )
    message: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[SosStatus] = mapped_column(
        _enum(SosStatus, "sos_status"), nullable=False, default=SosStatus.CREATED
    )

    # Serves the SOS queue: most urgent first, then most recently raised. No
    # denormalised integer is needed here - unlike hazard severity and task
    # priority, CRITICAL/HIGH/MEDIUM already sort correctly both as a
    # PostgreSQL enum (declaration order) and as the stored label on SQLite.
    __table_args__ = (Index("ix_sos_events_priority_raised_at", "priority", "raised_at"),)

    def __repr__(self) -> str:  # pragma: no cover - debugging aid
        return f"<SosEvent {self.sos_code} {self.priority.value}>"
