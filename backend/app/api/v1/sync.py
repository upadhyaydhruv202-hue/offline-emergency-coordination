from __future__ import annotations

import json
import uuid
from datetime import UTC, datetime

from fastapi import APIRouter, status
from pydantic import BaseModel, Field
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.api.deps import CurrentUser, DbSession
from app.core.errors import AppError
from app.models.enums import (
    ConflictResolutionKind,
    SyncEntityType,
    SyncOperationType,
    SyncQueueStatus,
)
from app.models.sync_conflict import SyncConflict
from app.models.sync_operation import SyncOperation
from app.services.sync_crdt import compare_operations

router = APIRouter(prefix="/sync", tags=["Sync"])


class SyncOperationIn(BaseModel):
    operation_id: uuid.UUID
    device_id: str = Field(min_length=3, max_length=64)
    actor_id: str = Field(min_length=1, max_length=128)
    entity_type: SyncEntityType
    entity_id: str = Field(min_length=8, max_length=64)
    operation_type: SyncOperationType
    payload: dict
    version: int = Field(ge=0)
    logical_timestamp: int = Field(ge=0)
    parent_version: int | None = Field(default=None, ge=0)


class SyncPushRequest(BaseModel):
    operations: list[SyncOperationIn]


class SyncStatusRead(BaseModel):
    pending: int
    acknowledged: int
    failed: int
    conflicts: int
    last_push_at: datetime | None = None
    note: str = "Peer ingest only. This is not live mesh networking."


class SyncConflictRead(BaseModel):
    id: uuid.UUID
    entity_type: SyncEntityType
    entity_id: str
    resolution: ConflictResolutionKind
    winner_operation_id: uuid.UUID
    loser_operation_id: uuid.UUID
    reason: str
    detected_at: datetime

    model_config = {"from_attributes": True}


@router.get("/status", response_model=SyncStatusRead)
def sync_status(session: DbSession, _: CurrentUser) -> SyncStatusRead:
    def _count(value: SyncQueueStatus) -> int:
        return session.scalar(
            select(func.count()).select_from(SyncOperation).where(SyncOperation.queue_status == value)
        ) or 0

    conflicts = session.scalar(select(func.count()).select_from(SyncConflict)) or 0
    last = session.scalar(select(func.max(SyncOperation.updated_at)))
    return SyncStatusRead(
        pending=_count(SyncQueueStatus.PENDING),
        acknowledged=_count(SyncQueueStatus.ACKNOWLEDGED),
        failed=_count(SyncQueueStatus.FAILED),
        conflicts=conflicts,
        last_push_at=last,
    )


@router.get("/conflicts", response_model=list[SyncConflictRead])
def list_conflicts(session: DbSession, _: CurrentUser) -> list[SyncConflict]:
    return list(session.scalars(select(SyncConflict).order_by(SyncConflict.detected_at.desc())).all())


class SyncPullRequest(BaseModel):
    since_logical_timestamp: int = Field(default=0, ge=0)


@router.post("/pull")
def pull_operations_post(body: SyncPullRequest, session: DbSession, _: CurrentUser) -> dict:
    return _pull(session, body.since_logical_timestamp)


@router.get("/pull")
def pull_operations(session: DbSession, _: CurrentUser, since: int = 0) -> dict:
    return _pull(session, since)


def _pull(session: Session, since: int) -> dict:
    rows = list(
        session.scalars(
            select(SyncOperation)
            .where(SyncOperation.logical_timestamp >= since)
            .order_by(SyncOperation.logical_timestamp)
        ).all()
    )
    return {
        "items": [
            {
                "operation_id": str(row.operation_id),
                "device_id": row.device_id,
                "entity_type": row.entity_type.value,
                "entity_id": row.entity_id,
                "operation_type": row.operation_type.value,
                "payload": json.loads(row.payload_json),
                "logical_timestamp": row.logical_timestamp,
                "queue_status": row.queue_status.value,
            }
            for row in rows
        ],
        "total": len(rows),
    }


@router.post("/push", status_code=status.HTTP_202_ACCEPTED)
def push_operations(body: SyncPushRequest, session: DbSession, _: CurrentUser) -> dict:
    accepted = 0
    conflicts = 0
    now = datetime.now(UTC)
    for item in body.operations:
        if not item.payload:
            raise AppError("Empty payload")
        existing = session.scalar(
            select(SyncOperation).where(SyncOperation.operation_id == item.operation_id)
        )
        if existing is not None:
            continue
        row = SyncOperation(
            id=item.operation_id,
            operation_id=item.operation_id,
            device_id=item.device_id,
            actor_id=item.actor_id,
            entity_type=item.entity_type,
            entity_id=item.entity_id,
            operation_type=item.operation_type,
            payload_json=json.dumps(item.payload),
            queue_status=SyncQueueStatus.ACKNOWLEDGED,
            version=item.version,
            logical_timestamp=item.logical_timestamp,
            parent_version=item.parent_version,
        )
        session.add(row)
        session.flush()
        accepted += 1

        siblings = list(
            session.scalars(
                select(SyncOperation).where(
                    SyncOperation.entity_id == item.entity_id,
                    SyncOperation.device_id != item.device_id,
                )
            ).all()
        )
        for other in siblings:
            if compare_operations(row, other) == 0:
                continue
            winner, loser = (row, other) if compare_operations(row, other) > 0 else (other, row)
            resolution = (
                ConflictResolutionKind.LAST_WRITER_WINS
                if winner.logical_timestamp != loser.logical_timestamp
                else ConflictResolutionKind.DEVICE_TIE_BREAK
            )
            session.add(
                SyncConflict(
                    entity_type=item.entity_type,
                    entity_id=item.entity_id,
                    operation_a_id=other.operation_id,
                    operation_b_id=row.operation_id,
                    detected_at=now,
                    resolution=resolution,
                    winner_operation_id=winner.operation_id,
                    loser_operation_id=loser.operation_id,
                    reason="Deterministic LWW on the coordination peer.",
                    resolved_at=now,
                )
            )
            conflicts += 1
    session.commit()
    return {"accepted": accepted, "conflicts_recorded": conflicts, "kind": "PEER_INGEST"}


@router.get("/demo-scenario")
def demo_scenario(_: CurrentUser) -> dict:
    """Judge-facing Road R-12 story. Not ingested field traffic."""
    return {
        "kind": "DEVELOPMENT_SCENARIO",
        "transport": "SIMULATED",
        "incident": "Ahmedabad Earthquake Response",
        "zone": "04",
        "entity": "Road R-12",
        "entity_id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeee0012",
        "device_a": {
            "device_id": "DRP-ALPHA001",
            "actor": "Responder Alpha",
            "type": "ROAD_BLOCKED",
            "severity": "HIGH",
        },
        "device_b": {
            "device_id": "DRP-BRAVO001",
            "actor": "Responder Bravo",
            "type": "PARTIALLY_ACCESSIBLE",
            "severity": "MEDIUM",
        },
        "resolution": "LAST_WRITER_WINS",
        "winner_device": "DRP-BRAVO001",
        "final_state": {"type": "PARTIALLY_ACCESSIBLE", "severity": "MEDIUM"},
        "note": (
            "Winner follows logical timestamp, then device id, then operation id. "
            "This is deterministic conflict resolution, not mesh networking."
        ),
    }

