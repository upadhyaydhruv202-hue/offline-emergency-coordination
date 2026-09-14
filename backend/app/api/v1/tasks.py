"""Task endpoints.

These serve the command centre and receive uploads from handsets. A team that
cannot reach this API still holds its tasks in the device's own SQLite.
"""

from __future__ import annotations

import uuid
from typing import Annotated

from fastapi import APIRouter, Query, status

from app.api.deps import CurrentUser, TaskServiceDep
from app.models.enums import TaskPriority, TaskStatus
from app.schemas.task import TaskBoard, TaskCreate, TaskPage, TaskRead, TaskUpdate

router = APIRouter(prefix="/tasks", tags=["Tasks"])


@router.get("", response_model=TaskPage, summary="List tasks, most urgent first")
def list_tasks(
    task_service: TaskServiceDep,
    _: CurrentUser,
    search: Annotated[str | None, Query(max_length=200)] = None,
    priority: TaskPriority | None = None,
    task_status: Annotated[TaskStatus | None, Query(alias="status")] = None,
    assigned_to: Annotated[str | None, Query(max_length=64)] = None,
    limit: Annotated[int, Query(ge=1, le=500)] = 100,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> TaskPage:
    return task_service.page(
        search=search,
        priority=priority,
        status=task_status,
        assigned_to=assigned_to,
        limit=limit,
        offset=offset,
    )


@router.get("/board", response_model=TaskBoard, summary="Counts by task status")
def task_board(task_service: TaskServiceDep, _: CurrentUser) -> TaskBoard:
    return task_service.board()


@router.get("/{task_id}", response_model=TaskRead, summary="One task")
def read_task(task_id: uuid.UUID, task_service: TaskServiceDep, _: CurrentUser) -> TaskRead:
    return TaskRead.model_validate(task_service.get(task_id))


@router.post(
    "",
    response_model=TaskRead,
    status_code=status.HTTP_201_CREATED,
    summary="Upload a task written on a device",
)
def create_task(payload: TaskCreate, task_service: TaskServiceDep, _: CurrentUser) -> TaskRead:
    return TaskRead.model_validate(task_service.register(payload))


@router.patch("/{task_id}", response_model=TaskRead, summary="Reassign or progress a task")
def update_task(
    task_id: uuid.UUID,
    payload: TaskUpdate,
    task_service: TaskServiceDep,
    _: CurrentUser,
) -> TaskRead:
    return TaskRead.model_validate(task_service.update(task_id, payload))
