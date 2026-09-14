"""Database access for :class:`~app.models.task.Task`."""

from __future__ import annotations

from sqlalchemy import func, or_, select

from app.models.enums import TaskPriority, TaskStatus
from app.models.task import Task
from app.repositories.base import BaseRepository


class TaskRepository(BaseRepository[Task]):
    model = Task

    def get_by_code(self, task_code: str) -> Task | None:
        stmt = select(Task).where(Task.task_code == task_code.strip())
        return self.session.scalars(stmt).first()

    def search(
        self,
        *,
        search: str | None = None,
        priority: TaskPriority | None = None,
        status: TaskStatus | None = None,
        assigned_to: str | None = None,
        limit: int = 100,
        offset: int = 0,
    ) -> list[Task]:
        """Most urgent first, then most recently written.

        Sorts on the denormalised ``rank`` rather than the priority label so
        the order is the same on PostgreSQL and SQLite.
        """
        stmt = (
            self._filtered(
                search=search, priority=priority, status=status, assigned_to=assigned_to
            )
            .order_by(Task.rank.asc(), Task.created_at.desc())
            .limit(limit)
            .offset(offset)
        )
        return list(self.session.scalars(stmt))

    def count(
        self,
        *,
        search: str | None = None,
        priority: TaskPriority | None = None,
        status: TaskStatus | None = None,
        assigned_to: str | None = None,
    ) -> int:
        stmt = self._filtered(
            search=search, priority=priority, status=status, assigned_to=assigned_to
        ).with_only_columns(func.count(Task.id))
        return self.session.scalar(stmt) or 0

    def count_by_status(self) -> dict[TaskStatus, int]:
        """Totals for every status, including the ones with no tasks."""
        stmt = select(Task.status, func.count(Task.id)).group_by(Task.status)
        counted = dict.fromkeys(TaskStatus, 0)
        for status, total in self.session.execute(stmt):
            counted[TaskStatus(status)] = total
        return counted

    def _filtered(
        self,
        *,
        search: str | None,
        priority: TaskPriority | None,
        status: TaskStatus | None,
        assigned_to: str | None,
    ):
        stmt = select(Task)
        if priority is not None:
            stmt = stmt.where(Task.priority == priority)
        if status is not None:
            stmt = stmt.where(Task.status == status)

        assignee = (assigned_to or "").strip()
        if assignee:
            # Exact match: "my tasks" on a handset must not pick up another
            # team whose name happens to contain this one's.
            stmt = stmt.where(Task.assigned_to == assignee)

        term = (search or "").strip()
        if term:
            pattern = f"%{term.lower()}%"
            stmt = stmt.where(
                or_(
                    func.lower(Task.task_code).like(pattern),
                    func.lower(Task.title).like(pattern),
                    func.lower(Task.location).like(pattern),
                )
            )
        return stmt
