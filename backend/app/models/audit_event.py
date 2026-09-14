"""Operational activity recorded for the command-centre feed.

This is not a cryptographic audit log. It is a chronological COP feed built
from seed and service events so the dashboard is not a disconnected fake
timeline.
"""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, Enum, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin, UuidPrimaryKeyMixin
from app.models.enums import AuditSeverity


def _enum(enum_cls: type, name: str) -> Enum:
    return Enum(
        enum_cls,
        name=name,
        values_callable=lambda cls: [member.value for member in cls],
        native_enum=False,
        length=16,
    )


class AuditEvent(UuidPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "audit_events"

    category: Mapped[str] = mapped_column(String(32), nullable=False, index=True)
    summary: Mapped[str] = mapped_column(Text, nullable=False)
    severity: Mapped[AuditSeverity] = mapped_column(
        _enum(AuditSeverity, "audit_severity"), nullable=False, default=AuditSeverity.INFO
    )
    entity_type: Mapped[str | None] = mapped_column(String(32), nullable=True)
    entity_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    actor_id: Mapped[str | None] = mapped_column(String(128), nullable=True)
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)

    def __repr__(self) -> str:  # pragma: no cover
        return f"<AuditEvent {self.category} {self.summary[:40]}>"
