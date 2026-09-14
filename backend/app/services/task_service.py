"""Task use-cases.

A task may be written on a commander's handset while it is offline, so this
service is an idempotent receiver and a read model - the same stance as
:mod:`app.services.victim_service`.
"""

from __future__ import annotations

import uuid

from sqlalchemy.orm import Session

from app.core.errors import NotFoundError
from app.models.enums import TaskPriority, TaskStatus
from app.models.task import Task
from app.repositories.incident_repository import IncidentRepository
from app.repositories.task_repository import TaskRepository
from app.schemas.task import (
    TaskBoard,
    TaskCreate,
    TaskPage,
    TaskRead,
    TaskStatusCounts,
    TaskUpdate,
)


class TaskService:
    def __init__(self, session: Session) -> None:
        self.session = session
        self.tasks = TaskRepository(session)
        self.incidents = IncidentRepository(session)

    def register(self, payload: TaskCreate) -> Task:
        """Store an uploaded task, or refresh the copy already held.

        A device with an intermittent link will retry an upload it is not sure
        landed. Re-sending the same UUID has to be harmless, so this updates
        in place instead of raising a conflict.
        """
        existing = self.tasks.get(payload.id)
        if existing is not None:
            return self._apply(existing, payload)

        self._require_known_incident(payload.incident_id)

        task = Task(
            id=payload.id,
            task_code=payload.task_code,
            incident_id=payload.incident_id,
            assigned_to=_blank_to_none(payload.assigned_to),
            title=payload.title,
            description=_blank_to_none(payload.description),
            priority=payload.priority,
            rank=payload.priority.priority,
            status=payload.status,
            location=_blank_to_none(payload.location),
        )
        if payload.created_at is not None:
            # Preserve when the task was actually written, which may be hours
            # before the device found a link.
            task.created_at = payload.created_at

        created = self.tasks.add(task)
        self.session.commit()
        self.session.refresh(created)
        return created

    def update(self, task_id: uuid.UUID, payload: TaskUpdate) -> Task:
        return self._apply(self.get(task_id), payload)

    def get(self, task_id: uuid.UUID) -> Task:
        task = self.tasks.get(task_id)
        if task is None:
            raise NotFoundError("No task with that identifier")
        return task

    def page(
        self,
        *,
        search: str | None = None,
        priority: TaskPriority | None = None,
        status: TaskStatus | None = None,
        assigned_to: str | None = None,
        limit: int = 100,
        offset: int = 0,
    ) -> TaskPage:
        items = self.tasks.search(
            search=search,
            priority=priority,
            status=status,
            assigned_to=assigned_to,
            limit=limit,
            offset=offset,
        )
        return TaskPage(
            items=[TaskRead.model_validate(task) for task in items],
            total=self.tasks.count(
                search=search, priority=priority, status=status, assigned_to=assigned_to
            ),
        )

    def board(self) -> TaskBoard:
        """Counts across every task, ignoring whatever filter is applied.

        A command centre filtering to COMPLETED still needs to see how much
        work is outstanding.
        """
        by_status = self.tasks.count_by_status()
        closed = sum(total for status, total in by_status.items() if status.is_closed)
        total = sum(by_status.values())

        return TaskBoard(
            total=total,
            open_tasks=total - closed,
            by_status=TaskStatusCounts(
                pending=by_status[TaskStatus.PENDING],
                accepted=by_status[TaskStatus.ACCEPTED],
                in_progress=by_status[TaskStatus.IN_PROGRESS],
                completed=by_status[TaskStatus.COMPLETED],
                cancelled=by_status[TaskStatus.CANCELLED],
            ),
        )

    def _apply(self, task: Task, payload: TaskCreate | TaskUpdate) -> Task:
        # Read attributes rather than dumping: a dump would flatten the enums
        # to plain strings and lose `TaskPriority.priority`. Only the fields
        # the caller actually sent are touched, so a PATCH stays partial.
        changed = payload.model_fields_set - _IMMUTABLE
        if "incident_id" in changed:
            self._require_known_incident(payload.incident_id)

        for field in changed:
            value = getattr(payload, field)
            setattr(task, field, _blank_to_none(value) if type(value) is str else value)

        if "priority" in changed:
            task.rank = task.priority.priority

        self.session.add(task)
        self.session.commit()
        self.session.refresh(task)
        return task

    def _require_known_incident(self, incident_id: uuid.UUID | None) -> None:
        """Reject a link to an incident this peer has never received.

        The foreign key would raise an opaque integrity error instead, and the
        fix is the same either way: upload the incident first.
        """
        if incident_id is None:
            return
        if self.incidents.get(incident_id) is None:
            raise NotFoundError(
                "No incident with that identifier",
                details={"incident_id": str(incident_id)},
            )


def _blank_to_none(value: str | None) -> str | None:
    """Treat an empty field as unrecorded rather than as an empty string."""
    if value is None:
        return None
    stripped = value.strip()
    return stripped or None


# Identity travels with the record from the device; an update may not rewrite
# it. ``rank`` is excluded because it is derived from ``priority``.
_IMMUTABLE = frozenset({"id", "task_code", "created_at", "rank"})
