"""Wire representations of :class:`~app.models.task.Task`.

``rank`` is exposed read-only: it is derived from ``priority`` so that a
client sorting locally reproduces the server's order without having to know
the enum's declaration order.
"""

from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.models.enums import TaskPriority, TaskStatus


class TaskBase(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    incident_id: uuid.UUID | None = None
    assigned_to: str | None = Field(default=None, max_length=64)
    title: str = Field(min_length=1, max_length=200)
    description: str | None = Field(default=None, max_length=2000)
    priority: TaskPriority
    status: TaskStatus = TaskStatus.PENDING
    location: str | None = Field(default=None, max_length=200)


class TaskCreate(TaskBase):
    """An upload of a task written on a device.

    ``id`` and ``task_code`` are minted on the handset, because a commander
    dictates a task by its code the moment it is written.
    """

    id: uuid.UUID
    task_code: str = Field(min_length=1, max_length=32)
    created_at: datetime | None = None


class TaskUpdate(BaseModel):
    """A partial update. Omitted fields are left as they are."""

    model_config = ConfigDict(str_strip_whitespace=True)

    incident_id: uuid.UUID | None = None
    assigned_to: str | None = Field(default=None, max_length=64)
    title: str | None = Field(default=None, min_length=1, max_length=200)
    description: str | None = Field(default=None, max_length=2000)
    priority: TaskPriority | None = None
    status: TaskStatus | None = None
    location: str | None = Field(default=None, max_length=200)


class TaskRead(TaskBase):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    task_code: str
    rank: int
    created_at: datetime
    updated_at: datetime


class TaskStatusCounts(BaseModel):
    """Counts per status, always with all five keys present."""

    pending: int = 0
    accepted: int = 0
    in_progress: int = 0
    completed: int = 0
    cancelled: int = 0


class TaskBoard(BaseModel):
    """The command-centre summary above the task board."""

    total: int = 0
    open_tasks: int = 0
    by_status: TaskStatusCounts = TaskStatusCounts()


class TaskPage(BaseModel):
    items: list[TaskRead]
    total: int
