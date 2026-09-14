"""Work assigned to a team.

Like every field-operations table this is a destination for records minted on
a device: a commander writes a task offline and it is uploaded with the
identity it already has.
"""

from __future__ import annotations

import uuid

from sqlalchemy import Enum, ForeignKey, Integer, String, Text, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin, UuidPrimaryKeyMixin
from app.models.enums import TaskPriority, TaskStatus


def _enum(enum_cls: type, name: str) -> Enum:
    return Enum(
        enum_cls,
        name=name,
        values_callable=lambda cls: [member.value for member in cls],
    )


class Task(UuidPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "tasks"

    task_code: Mapped[str] = mapped_column(String(32), unique=True, index=True, nullable=False)

    # Nullable and ``SET NULL`` on delete: an unassigned task still has to be
    # visible so it can be picked up.
    incident_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("incidents.id", ondelete="SET NULL"), nullable=True
    )

    # Free text, like the ``created_by`` columns elsewhere: a task is assigned
    # to a team or a device session, which need not exist in ``users``.
    assigned_to: Mapped[str | None] = mapped_column(String(64), nullable=True)

    title: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)

    priority: Mapped[TaskPriority] = mapped_column(
        _enum(TaskPriority, "task_priority"), nullable=False
    )

    # Denormalised :attr:`TaskPriority.priority`. Named ``rank`` because
    # ``priority`` is already taken by the enum on this table; the reasoning is
    # the same as ``hazards.priority``.
    rank: Mapped[int] = mapped_column(Integer, nullable=False)

    status: Mapped[TaskStatus] = mapped_column(
        _enum(TaskStatus, "task_status"), nullable=False, default=TaskStatus.PENDING
    )

    # A description of where, not a coordinate: "Sector 7, behind the school"
    # is what a commander dictates and what a team can act on.
    location: Mapped[str | None] = mapped_column(String(200), nullable=True)

    def __repr__(self) -> str:  # pragma: no cover - debugging aid
        return f"<Task {self.task_code} {self.status.value}>"
