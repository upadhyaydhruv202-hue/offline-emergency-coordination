"""The event everything else in the field hangs off.

Like :class:`~app.models.victim.Victim` this table is a *destination*: an
incident is declared on a device, given a code that is already being used on
the radio, and uploaded afterwards. The primary key is therefore the UUID
minted on that device.
"""

from __future__ import annotations

from sqlalchemy import Enum, Float, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin, UuidPrimaryKeyMixin
from app.models.enums import DisasterType, IncidentStatus


def _enum(enum_cls: type, name: str) -> Enum:
    return Enum(
        enum_cls,
        name=name,
        values_callable=lambda cls: [member.value for member in cls],
    )


class Incident(UuidPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "incidents"

    # Spoken over the radio and written on paper, e.g. ``INC-2026-014``.
    incident_code: Mapped[str] = mapped_column(String(32), unique=True, index=True, nullable=False)

    title: Mapped[str] = mapped_column(String(200), nullable=False)
    disaster_type: Mapped[DisasterType] = mapped_column(
        _enum(DisasterType, "disaster_type"), nullable=False
    )
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[IncidentStatus] = mapped_column(
        _enum(IncidentStatus, "incident_status"), nullable=False, default=IncidentStatus.ACTIVE
    )

    # Free text rather than a zones table: a zone is named by whoever is
    # commanding, and inventing a taxonomy up front would be guesswork.
    assigned_zone: Mapped[str | None] = mapped_column(String(120), nullable=True)

    latitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    longitude: Mapped[float | None] = mapped_column(Float, nullable=True)

    # The authoring session, kept as free text for the same reason as on
    # ``victims``: an offline device has a session id that is not in ``users``.
    created_by: Mapped[str] = mapped_column(String(64), nullable=False)

    # Who last changed the incident, which for a shared record is a different
    # question from who opened it.
    last_modified_by: Mapped[str | None] = mapped_column(String(64), nullable=True)

    def __repr__(self) -> str:  # pragma: no cover - debugging aid
        return f"<Incident {self.incident_code} {self.status.value}>"
