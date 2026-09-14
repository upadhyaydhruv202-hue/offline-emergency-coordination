"""Last known field position and availability for a roster account.

One row per user. Devices do not auto-upload; seed and explicit PATCH populate
this for the operational map.
"""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, Float, ForeignKey, String, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin, UuidPrimaryKeyMixin
from app.models.enums import ResponderStatus


def _enum(enum_cls: type, name: str) -> Enum:
    return Enum(
        enum_cls,
        name=name,
        values_callable=lambda cls: [member.value for member in cls],
        native_enum=False,
        length=32,
    )


class ResponderPresence(UuidPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "responder_presences"

    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False
    )
    status: Mapped[ResponderStatus] = mapped_column(
        _enum(ResponderStatus, "responder_status"), nullable=False, default=ResponderStatus.AVAILABLE
    )
    latitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    longitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    last_seen_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    device_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    assigned_incident_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("incidents.id", ondelete="SET NULL"), nullable=True
    )
    assigned_task: Mapped[str | None] = mapped_column(String(160), nullable=True)

    def __repr__(self) -> str:  # pragma: no cover
        return f"<ResponderPresence {self.user_id} {self.status.value}>"
