"""Slice 4 peer ingest: push, pull, status, deterministic conflict records.

The coordination backend is a peer, not the source of truth during a partition.
These endpoints exist so a later transport can dump operations here. They are
not live mesh networking.
"""

from __future__ import annotations

import uuid

from fastapi.testclient import TestClient

from app.models.enums import SyncEntityType, SyncOperationType, SyncQueueStatus
from app.models.sync_operation import SyncOperation
from app.services.sync_crdt import compare_operations

PUSH = "/api/v1/sync/push"
PULL = "/api/v1/sync/pull"
STATUS = "/api/v1/sync/status"
CONFLICTS = "/api/v1/sync/conflicts"
DEMO = "/api/v1/sync/demo-scenario"


def _op(**overrides: object) -> dict[str, object]:
    body: dict[str, object] = {
        "operation_id": str(uuid.uuid4()),
        "device_id": "DRP-ALPHA001",
        "actor_id": "responder-alpha",
        "entity_type": "HAZARD",
        "entity_id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeee0012",
        "operation_type": "UPDATE",
        "payload": {"type": "ROAD_BLOCKED", "severity": "HIGH"},
        "version": 2,
        "logical_timestamp": 2,
        "parent_version": 1,
    }
    body.update(overrides)
    return body


def test_sync_requires_authentication(client: TestClient) -> None:
    assert client.get(STATUS).status_code == 401
    assert client.post(PUSH, json={"operations": []}).status_code == 401


def test_empty_push_and_status(client: TestClient, auth_headers: dict[str, str]) -> None:
    accepted = client.post(PUSH, json={"operations": []}, headers=auth_headers)
    assert accepted.status_code == 202
    status = client.get(STATUS, headers=auth_headers).json()
    assert status["pending"] == 0
    assert status["acknowledged"] == 0
    assert "not live mesh" in status["note"].lower()


def test_duplicate_operation_is_idempotent(client: TestClient, auth_headers: dict[str, str]) -> None:
    op = _op()
    first = client.post(PUSH, json={"operations": [op]}, headers=auth_headers)
    second = client.post(PUSH, json={"operations": [op]}, headers=auth_headers)
    assert first.json()["accepted"] == 1
    assert second.json()["accepted"] == 0
    pulled = client.post(PULL, json={"since_logical_timestamp": 0}, headers=auth_headers)
    assert pulled.json()["total"] == 1


def test_malformed_payload_rejected(client: TestClient, auth_headers: dict[str, str]) -> None:
    op = _op(payload={})
    response = client.post(PUSH, json={"operations": [op]}, headers=auth_headers)
    assert response.status_code == 400


def test_road_r12_conflict_is_recorded(client: TestClient, auth_headers: dict[str, str]) -> None:
    a = _op(
        device_id="DRP-ALPHA001",
        payload={"type": "ROAD_BLOCKED", "severity": "HIGH"},
        logical_timestamp=2,
    )
    b = _op(
        device_id="DRP-BRAVO001",
        payload={"type": "PARTIALLY_ACCESSIBLE", "severity": "MEDIUM"},
        logical_timestamp=2,
    )
    client.post(PUSH, json={"operations": [a, b]}, headers=auth_headers)
    conflicts = client.get(CONFLICTS, headers=auth_headers).json()
    assert len(conflicts) == 1
    assert conflicts[0]["entity_id"] == "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeee0012"
    # Equal timestamps: lexicographic device id, BRAVO > ALPHA.
    assert conflicts[0]["winner_operation_id"] == b["operation_id"]
    status = client.get(STATUS, headers=auth_headers).json()
    assert status["conflicts"] == 1
    assert status["acknowledged"] == 2


def test_demo_scenario_is_labelled_simulated(client: TestClient, auth_headers: dict[str, str]) -> None:
    body = client.get(DEMO, headers=auth_headers).json()
    assert body["kind"] == "DEVELOPMENT_SCENARIO"
    assert body["transport"] == "SIMULATED"
    assert body["entity"] == "Road R-12"


def test_compare_operations_is_a_total_order() -> None:
    def make(device: str, ts: int, op: str) -> SyncOperation:
        return SyncOperation(
            operation_id=uuid.UUID(op),
            device_id=device,
            actor_id="actor",
            entity_type=SyncEntityType.HAZARD,
            entity_id="aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeee0012",
            operation_type=SyncOperationType.UPDATE,
            payload_json="{}",
            queue_status=SyncQueueStatus.PENDING,
            version=ts,
            logical_timestamp=ts,
        )

    earlier = make("DRP-BRAVO001", 1, "00000000-0000-4000-8000-00000000000b")
    later = make("DRP-ALPHA001", 2, "00000000-0000-4000-8000-00000000000a")
    assert compare_operations(earlier, later) < 0

    alpha = make("DRP-ALPHA001", 2, "00000000-0000-4000-8000-00000000000a")
    bravo = make("DRP-BRAVO001", 2, "00000000-0000-4000-8000-00000000000b")
    assert compare_operations(alpha, bravo) < 0
    assert compare_operations(bravo, alpha) > 0

    low = make("DRP-ALPHA001", 2, "00000000-0000-4000-8000-00000000000a")
    high = make("DRP-ALPHA001", 2, "00000000-0000-4000-8000-00000000000f")
    assert compare_operations(low, high) < 0
    assert compare_operations(low, low) == 0
