"""Slice 5 command-centre COP: snapshot, facilities, activity, RBAC on writes."""

from __future__ import annotations

import uuid

from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.models.enums import UserRole
from app.schemas.user import UserCreate
from app.services.auth_service import AuthService
from tests.conftest import TEST_PASSWORD

SNAPSHOT = "/api/v1/command/snapshot"
FACILITIES = "/api/v1/facilities"
AUDIT = "/api/v1/audit/events"
SYNC_OPS = "/api/v1/sync/operations"


def test_snapshot_requires_auth(client: TestClient) -> None:
    assert client.get(SNAPSHOT).status_code == 401


def test_empty_snapshot_kpis(client: TestClient, auth_headers: dict[str, str]) -> None:
    body = client.get(SNAPSHOT, headers=auth_headers).json()
    assert body["kpis"]["active_incidents"] == 0
    assert body["kpis"]["critical_victims"] == 0
    assert body["sync"]["transport"] == "SIMULATED SYNC"
    assert "not live mesh" in body["sync"]["note"].lower()
    assert "incidents" in body["layers"]
    assert body["markers"] == []


def test_volunteer_cannot_create_facility(
    client: TestClient, session: Session, auth_headers: dict[str, str]
) -> None:
    volunteer = AuthService(session).register(
        UserCreate(
            email="vol@example.com",
            full_name="Volunteer",
            role=UserRole.VOLUNTEER,
            password=TEST_PASSWORD,
        )
    )
    session.commit()
    token = AuthService(session).issue_tokens(volunteer).access_token
    payload = {
        "id": str(uuid.uuid4()),
        "facility_code": "HSP-TEST-1",
        "kind": "HOSPITAL",
        "name": "Test Hospital",
        "status": "OPEN",
        "capacity_total": 10,
        "occupancy": 2,
        "emergency_available": True,
        "latitude": 23.03,
        "longitude": 72.57,
    }
    denied = client.post(FACILITIES, json=payload, headers={"Authorization": f"Bearer {token}"})
    assert denied.status_code == 403

    commander = AuthService(session).register(
        UserCreate(
            email="ic@example.com",
            full_name="Commander",
            role=UserRole.INCIDENT_COMMANDER,
            password=TEST_PASSWORD,
        )
    )
    session.commit()
    ic_token = AuthService(session).issue_tokens(commander).access_token
    created = client.post(
        FACILITIES, json=payload, headers={"Authorization": f"Bearer {ic_token}"}
    )
    assert created.status_code == 201
    assert created.json()["remaining"] == 8

    listed = client.get(f"{FACILITIES}?kind=HOSPITAL", headers=auth_headers).json()
    assert listed["total"] == 1
    assert listed["board"]["hospital_beds_remaining"] == 8

    snap = client.get(SNAPSHOT, headers=auth_headers).json()
    assert snap["kpis"]["hospital_beds_remaining"] == 8
    assert any(marker["layer"] == "hospitals" for marker in snap["markers"])


def test_audit_and_sync_operations_empty(client: TestClient, auth_headers: dict[str, str]) -> None:
    assert client.get(AUDIT, headers=auth_headers).json()["total"] == 0
    ops = client.get(SYNC_OPS, headers=auth_headers).json()
    assert ops["total"] == 0
    assert ops["items"] == []
