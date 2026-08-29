"""A casualty registered by a responder.

The handset is the system of record while a device is offline, so this table
is a *destination* for records that already exist elsewhere: the primary key
is the UUID minted on the device, not one generated here.
"""

from __future__ import annotations

from sqlalchemy import Enum, Float, Index, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin, UuidPrimaryKeyMixin
from app.models.enums import AgeGroup, Gender, TriageCategory, VictimStatus


def _enum(enum_cls: type, name: str) -> Enum:
    return Enum(
        enum_cls,
        name=name,
        values_callable=lambda cls: [member.value for member in cls],
    )


class Victim(UuidPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "victims"

    # Written on a triage tag and read out over the radio, e.g. ``V-8C1F-007``.
    temporary_id: Mapped[str] = mapped_column(String(32), unique=True, index=True, nullable=False)

    # Unidentified casualties are the common case in the first hours and are
    # never a reason to hold up registration.
    name: Mapped[str | None] = mapped_column(String(160), nullable=True)
    age: Mapped[int | None] = mapped_column(Integer, nullable=True)
    age_group: Mapped[AgeGroup] = mapped_column(
        _enum(AgeGroup, "age_group"), nullable=False, default=AgeGroup.UNKNOWN
    )
    gender: Mapped[Gender] = mapped_column(
        _enum(Gender, "gender"), nullable=False, default=Gender.UNKNOWN
    )
    medical_condition: Mapped[str | None] = mapped_column(Text, nullable=True)
    injury_type: Mapped[str | None] = mapped_column(String(200), nullable=True)
    triage_category: Mapped[TriageCategory] = mapped_column(
        _enum(TriageCategory, "triage_category"), nullable=False
    )

    # Denormalised :attr:`TriageCategory.priority` so ordering by severity is a
    # plain indexed sort rather than a CASE expression.
    priority: Mapped[int] = mapped_column(Integer, nullable=False)

    assistance_required: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[VictimStatus] = mapped_column(
        _enum(VictimStatus, "victim_status"), nullable=False, default=VictimStatus.REGISTERED
    )

    # Reserved for the spatial slice; devices send null until then.
    latitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    longitude: Mapped[float | None] = mapped_column(Float, nullable=True)

    # The authoring session, kept as free text because an offline demo session
    # has a device-local id that does not exist in ``users``.
    created_by: Mapped[str] = mapped_column(String(64), nullable=False)

    __table_args__ = (Index("ix_victims_priority_updated_at", "priority", "updated_at"),)

    def __repr__(self) -> str:  # pragma: no cover - debugging aid
        return f"<Victim {self.temporary_id} {self.triage_category.value}>"
