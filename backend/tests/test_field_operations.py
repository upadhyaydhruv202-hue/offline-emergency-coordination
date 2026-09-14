"""Slice 3 field operations: incidents, hazards, SOS events and tasks.

Every POST in this slice is an idempotent upload of a record minted on a
device, so most of what is worth asserting is that identity, provenance and
ordering survive the trip - and that a retry from a handset with a flaky link
can never produce a second copy of a casualty report.
"""

from __future__ import annotations

import time
import uuid
from datetime import UTC, datetime, timedelta

import pytest
from fastapi.testclient import TestClient

from app.models.enums import HazardSeverity, SosPriority, TaskPriority

INCIDENTS_URL = "/api/v1/incidents"
HAZARDS_URL = "/api/v1/hazards"
SOS_URL = "/api/v1/sos"
TASKS_URL = "/api/v1/tasks"
RESPONDERS_URL = "/api/v1/responders"

COLLECTION_URLS = (INCIDENTS_URL, HAZARDS_URL, SOS_URL, TASKS_URL)


def _minutes_ago(minutes: int) -> str:
    return (datetime.now(UTC) - timedelta(minutes=minutes)).isoformat()


def _incident_payload(**overrides: object) -> dict[str, object]:
    """An incident as a handset would upload it: identifiers already minted."""
    body: dict[str, object] = {
        "id": str(uuid.uuid4()),
        "incident_code": f"INC-{uuid.uuid4().hex[:6].upper()}",
        "title": "Ahmedabad Earthquake Response",
        "disaster_type": "EARTHQUAKE",
        "assigned_zone": "Ahmedabad Zone 04",
        "created_by": "local-session-1",
    }
    body.update(overrides)
    return body


def _hazard_payload(**overrides: object) -> dict[str, object]:
    body: dict[str, object] = {
        "id": str(uuid.uuid4()),
        "hazard_code": f"HZ-{uuid.uuid4().hex[:6].upper()}",
        "reported_by": "local-session-1",
        "type": "ROAD_BLOCKED",
        "severity": "HIGH",
        "description": "Rubble blocking both lanes",
        "observed_at": _minutes_ago(30),
    }
    body.update(overrides)
    return body


def _sos_payload(**overrides: object) -> dict[str, object]:
    body: dict[str, object] = {
        "id": str(uuid.uuid4()),
        "sos_code": f"SOS-{uuid.uuid4().hex[:6].upper()}",
        "created_by": "local-session-1",
        "priority": "CRITICAL",
        "message": "Team of two trapped on the second floor",
        "raised_at": _minutes_ago(10),
    }
    body.update(overrides)
    return body


def _task_payload(**overrides: object) -> dict[str, object]:
    body: dict[str, object] = {
        "id": str(uuid.uuid4()),
        "task_code": f"TASK-{uuid.uuid4().hex[:6].upper()}",
        "title": "Search collapsed block, sector 7",
        "priority": "HIGH",
        "location": "Sector 7, behind the municipal school",
    }
    body.update(overrides)
    return body


# (url, payload factory, code field, a status the module can be advanced to).
MODULES = (
    (INCIDENTS_URL, _incident_payload, "incident_code", "PAUSED"),
    (HAZARDS_URL, _hazard_payload, "hazard_code", "VERIFIED"),
    (SOS_URL, _sos_payload, "sos_code", "ACKNOWLEDGED"),
    (TASKS_URL, _task_payload, "task_code", "ACCEPTED"),
)
MODULE_IDS = ("incidents", "hazards", "sos", "tasks")


def _create(client: TestClient, headers: dict[str, str], url: str, payload: dict) -> dict:
    response = client.post(url, json=payload, headers=headers)
    assert response.status_code == 201, response.text
    return response.json()


def _create_incident(client: TestClient, headers: dict[str, str], **overrides: object) -> dict:
    return _create(client, headers, INCIDENTS_URL, _incident_payload(**overrides))


def _create_hazard(client: TestClient, headers: dict[str, str], **overrides: object) -> dict:
    return _create(client, headers, HAZARDS_URL, _hazard_payload(**overrides))


def _create_sos(client: TestClient, headers: dict[str, str], **overrides: object) -> dict:
    return _create(client, headers, SOS_URL, _sos_payload(**overrides))


def _create_task(client: TestClient, headers: dict[str, str], **overrides: object) -> dict:
    return _create(client, headers, TASKS_URL, _task_payload(**overrides))


@pytest.mark.parametrize("url", COLLECTION_URLS, ids=MODULE_IDS)
def test_field_operation_endpoints_require_authentication(client: TestClient, url: str) -> None:
    assert client.get(url).status_code == 401
    assert client.get(f"{url}/board").status_code == 401
    assert client.get(f"{url}/{uuid.uuid4()}").status_code == 401


def test_the_responder_roster_requires_authentication(client: TestClient) -> None:
    assert client.get(RESPONDERS_URL).status_code == 401


@pytest.mark.parametrize(("url", "factory", "code_field", "_next"), MODULES, ids=MODULE_IDS)
def test_an_upload_requires_authentication(
    client: TestClient, url: str, factory, code_field: str, _next: str
) -> None:
    assert client.post(url, json=factory()).status_code == 401


@pytest.mark.parametrize(("url", "factory", "code_field", "_next"), MODULES, ids=MODULE_IDS)
def test_an_upload_keeps_the_identifiers_minted_on_the_device(
    client: TestClient,
    auth_headers: dict[str, str],
    url: str,
    factory,
    code_field: str,
    _next: str,
) -> None:
    payload = factory()

    body = _create(client, auth_headers, url, payload)

    assert body["id"] == payload["id"]
    assert body[code_field] == payload[code_field]


@pytest.mark.parametrize(("url", "factory", "code_field", "next_status"), MODULES, ids=MODULE_IDS)
def test_re_uploading_the_same_id_updates_rather_than_duplicating(
    client: TestClient,
    auth_headers: dict[str, str],
    url: str,
    factory,
    code_field: str,
    next_status: str,
) -> None:
    """A device with a flaky link retries; the retry must be harmless."""
    payload = factory()

    first = client.post(url, json=payload, headers=auth_headers)
    payload["status"] = next_status
    second = client.post(url, json=payload, headers=auth_headers)

    assert first.status_code == 201
    assert second.status_code == 201
    assert second.json()["status"] == next_status
    assert second.json()["id"] == payload["id"]
    assert client.get(url, headers=auth_headers).json()["total"] == 1


@pytest.mark.parametrize("url", COLLECTION_URLS, ids=MODULE_IDS)
def test_reading_an_unknown_record_is_a_404(
    client: TestClient, auth_headers: dict[str, str], url: str
) -> None:
    response = client.get(f"{url}/{uuid.uuid4()}", headers=auth_headers)

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "not_found"


@pytest.mark.parametrize(("url", "factory", "code_field", "next_status"), MODULES, ids=MODULE_IDS)
def test_a_patch_advances_the_status(
    client: TestClient,
    auth_headers: dict[str, str],
    url: str,
    factory,
    code_field: str,
    next_status: str,
) -> None:
    record = _create(client, auth_headers, url, factory())

    response = client.patch(
        f"{url}/{record['id']}", json={"status": next_status}, headers=auth_headers
    )

    assert response.status_code == 200, response.text
    assert response.json()["status"] == next_status


def test_a_patch_bumps_updated_at(client: TestClient, auth_headers: dict[str, str]) -> None:
    incident = _create_incident(client, auth_headers)

    # SQLite's CURRENT_TIMESTAMP has one-second resolution, so without this
    # pause the update would legitimately land in the same tick as the insert.
    time.sleep(1.1)
    patched = client.patch(
        f"{INCIDENTS_URL}/{incident['id']}", json={"status": "RESOLVED"}, headers=auth_headers
    ).json()

    assert datetime.fromisoformat(patched["updated_at"]) > datetime.fromisoformat(
        incident["updated_at"]
    )


def test_an_update_cannot_rewrite_provenance(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    incident = _create_incident(client, auth_headers)

    patched = client.patch(
        f"{INCIDENTS_URL}/{incident['id']}",
        json={
            "created_by": "someone-else",
            "last_modified_by": "commander-1",
            "title": "Corrected Title",
        },
        headers=auth_headers,
    ).json()

    assert patched["created_by"] == "local-session-1"
    assert patched["last_modified_by"] == "commander-1"
    assert patched["title"] == "Corrected Title"


def test_hazard_priority_is_derived_from_the_severity(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    critical = _create_hazard(client, auth_headers, severity="CRITICAL")
    low = _create_hazard(client, auth_headers, severity="LOW")

    assert critical["priority"] == HazardSeverity.CRITICAL.priority
    assert low["priority"] == HazardSeverity.LOW.priority
    assert low["priority"] > critical["priority"]


def test_a_reassessed_hazard_gets_a_new_priority(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    hazard = _create_hazard(client, auth_headers, severity="LOW")

    patched = client.patch(
        f"{HAZARDS_URL}/{hazard['id']}", json={"severity": "CRITICAL"}, headers=auth_headers
    ).json()

    assert patched["priority"] == HazardSeverity.CRITICAL.priority


def test_task_rank_is_derived_from_the_priority(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    critical = _create_task(client, auth_headers, priority="CRITICAL")
    low = _create_task(client, auth_headers, priority="LOW")

    assert critical["rank"] == TaskPriority.CRITICAL.priority
    assert low["rank"] == TaskPriority.LOW.priority


def test_a_repriorised_task_gets_a_new_rank(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    task = _create_task(client, auth_headers, priority="LOW")

    patched = client.patch(
        f"{TASKS_URL}/{task['id']}", json={"priority": "CRITICAL"}, headers=auth_headers
    ).json()

    assert patched["rank"] == TaskPriority.CRITICAL.priority


def test_the_hazard_list_is_ordered_most_severe_first(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    for index, severity in enumerate(("LOW", "MEDIUM", "CRITICAL", "HIGH")):
        _create_hazard(
            client,
            auth_headers,
            severity=severity,
            description=severity,
            observed_at=_minutes_ago(index * 10),
        )

    listed = client.get(HAZARDS_URL, headers=auth_headers).json()["items"]

    assert [hazard["description"] for hazard in listed] == [
        "CRITICAL",
        "HIGH",
        "MEDIUM",
        "LOW",
    ]


def test_the_sos_queue_is_ordered_most_urgent_first(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    for index, priority in enumerate(("MEDIUM", "CRITICAL", "HIGH")):
        _create_sos(
            client,
            auth_headers,
            priority=priority,
            message=priority,
            raised_at=_minutes_ago(index * 10),
        )

    listed = client.get(SOS_URL, headers=auth_headers).json()["items"]

    assert [sos["message"] for sos in listed] == ["CRITICAL", "HIGH", "MEDIUM"]


def test_the_task_list_is_ordered_most_urgent_first(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    for priority in ("LOW", "CRITICAL", "MEDIUM", "HIGH"):
        _create_task(client, auth_headers, priority=priority, title=priority)

    listed = client.get(TASKS_URL, headers=auth_headers).json()["items"]

    assert [task["title"] for task in listed] == ["CRITICAL", "HIGH", "MEDIUM", "LOW"]


def test_the_incident_list_is_ordered_most_recently_declared_first(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    _create_incident(client, auth_headers, title="Older", created_at=_minutes_ago(300))
    _create_incident(client, auth_headers, title="Newer", created_at=_minutes_ago(5))

    listed = client.get(INCIDENTS_URL, headers=auth_headers).json()["items"]

    assert [incident["title"] for incident in listed] == ["Newer", "Older"]


@pytest.mark.parametrize(
    ("query", "expected"),
    [
        ({"disaster_type": "FLOOD"}, ["Riverfront Flooding"]),
        ({"status": "PAUSED"}, ["Riverfront Flooding"]),
        ({"status": "RESOLVED"}, []),
        ({"search": "earthquake"}, ["Earthquake Response"]),
        ({"search": "zone 04"}, ["Earthquake Response"]),
    ],
)
def test_the_incident_list_filters_and_searches(
    client: TestClient,
    auth_headers: dict[str, str],
    query: dict[str, str],
    expected: list[str],
) -> None:
    _create_incident(
        client,
        auth_headers,
        title="Earthquake Response",
        disaster_type="EARTHQUAKE",
        assigned_zone="Ahmedabad Zone 04",
        created_at=_minutes_ago(300),
    )
    _create_incident(
        client,
        auth_headers,
        title="Riverfront Flooding",
        disaster_type="FLOOD",
        status="PAUSED",
        assigned_zone="Riverfront West",
        created_at=_minutes_ago(5),
    )

    listed = client.get(INCIDENTS_URL, params=query, headers=auth_headers).json()["items"]

    assert [incident["title"] for incident in listed] == expected


@pytest.mark.parametrize(
    ("query", "expected"),
    [
        ({"type": "FIRE"}, ["Fire on the top floor"]),
        ({"severity": "LOW"}, ["Rubble blocking both lanes"]),
        ({"status": "VERIFIED"}, ["Fire on the top floor"]),
        ({"status": "RESOLVED"}, []),
        ({"search": "rubble"}, ["Rubble blocking both lanes"]),
    ],
)
def test_the_hazard_list_filters_and_searches(
    client: TestClient,
    auth_headers: dict[str, str],
    query: dict[str, str],
    expected: list[str],
) -> None:
    _create_hazard(
        client,
        auth_headers,
        type="FIRE",
        severity="CRITICAL",
        status="VERIFIED",
        description="Fire on the top floor",
    )
    _create_hazard(client, auth_headers, type="ROAD_BLOCKED", severity="LOW")

    listed = client.get(HAZARDS_URL, params=query, headers=auth_headers).json()["items"]

    assert [hazard["description"] for hazard in listed] == expected


@pytest.mark.parametrize(
    ("query", "expected"),
    [
        ({"priority": "CRITICAL"}, ["Trapped"]),
        ({"priority": "MEDIUM"}, ["Low on supplies"]),
        ({"status": "ACKNOWLEDGED"}, ["Low on supplies"]),
        ({"status": "RESOLVED"}, []),
    ],
)
def test_the_sos_list_filters(
    client: TestClient,
    auth_headers: dict[str, str],
    query: dict[str, str],
    expected: list[str],
) -> None:
    _create_sos(client, auth_headers, priority="CRITICAL", message="Trapped")
    _create_sos(
        client,
        auth_headers,
        priority="MEDIUM",
        status="ACKNOWLEDGED",
        message="Low on supplies",
    )

    listed = client.get(SOS_URL, params=query, headers=auth_headers).json()["items"]

    assert [sos["message"] for sos in listed] == expected


@pytest.mark.parametrize(
    ("query", "expected"),
    [
        ({"priority": "CRITICAL"}, ["Search collapsed block"]),
        ({"status": "COMPLETED"}, ["Distribute water"]),
        ({"status": "CANCELLED"}, []),
        ({"assigned_to": "rescue-team-1"}, ["Search collapsed block"]),
        ({"search": "water"}, ["Distribute water"]),
        ({"search": "relief camp"}, ["Distribute water"]),
    ],
)
def test_the_task_list_filters_and_searches(
    client: TestClient,
    auth_headers: dict[str, str],
    query: dict[str, str],
    expected: list[str],
) -> None:
    _create_task(
        client,
        auth_headers,
        title="Search collapsed block",
        priority="CRITICAL",
        assigned_to="rescue-team-1",
        location="Sector 7",
    )
    _create_task(
        client,
        auth_headers,
        title="Distribute water",
        priority="MEDIUM",
        status="COMPLETED",
        assigned_to="volunteer-group-3",
        location="Relief camp, ward 12",
    )

    listed = client.get(TASKS_URL, params=query, headers=auth_headers).json()["items"]

    assert [task["title"] for task in listed] == expected


def test_the_assigned_to_filter_is_an_exact_match(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    """"My tasks" on a handset must not pick up another team's work."""
    _create_task(client, auth_headers, title="Mine", assigned_to="team-1")
    _create_task(client, auth_headers, title="Theirs", assigned_to="team-12")

    listed = client.get(
        TASKS_URL, params={"assigned_to": "team-1"}, headers=auth_headers
    ).json()["items"]

    assert [task["title"] for task in listed] == ["Mine"]


def test_the_incident_board_counts_every_status_including_empty_ones(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    _create_incident(client, auth_headers)
    _create_incident(client, auth_headers, status="PAUSED")

    board = client.get(f"{INCIDENTS_URL}/board", headers=auth_headers).json()

    assert board["total"] == 2
    assert board["by_status"] == {"active": 1, "paused": 1, "resolved": 0}


def test_the_hazard_board_ignores_the_active_list_filter(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    """Filtering to LOW must not hide how many critical hazards are open."""
    _create_hazard(client, auth_headers, severity="CRITICAL", status="VERIFIED")
    _create_hazard(client, auth_headers, severity="LOW")

    page = client.get(HAZARDS_URL, params={"severity": "LOW"}, headers=auth_headers).json()
    board = client.get(f"{HAZARDS_URL}/board", headers=auth_headers).json()

    assert page["total"] == 1
    assert board["total"] == 2
    assert board["by_severity"] == {"critical": 1, "high": 0, "medium": 0, "low": 1}
    assert board["by_status"] == {"reported": 1, "verified": 1, "resolved": 0}


def test_the_sos_board_ignores_the_active_list_filter(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    _create_sos(client, auth_headers, priority="CRITICAL")
    _create_sos(client, auth_headers, priority="MEDIUM", status="RESOLVED")

    page = client.get(SOS_URL, params={"status": "RESOLVED"}, headers=auth_headers).json()
    board = client.get(f"{SOS_URL}/board", headers=auth_headers).json()

    assert page["total"] == 1
    assert board["total"] == 2
    assert board["by_priority"] == {"critical": 1, "high": 0, "medium": 1}
    assert board["by_status"] == {"created": 1, "acknowledged": 0, "resolved": 1}


def test_the_task_board_ignores_the_active_list_filter(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    _create_task(client, auth_headers, priority="CRITICAL")
    _create_task(client, auth_headers, priority="LOW", status="COMPLETED")

    page = client.get(TASKS_URL, params={"status": "COMPLETED"}, headers=auth_headers).json()
    board = client.get(f"{TASKS_URL}/board", headers=auth_headers).json()

    assert page["total"] == 1
    assert board["total"] == 2
    assert board["open_tasks"] == 1
    assert board["by_status"] == {
        "pending": 1,
        "accepted": 0,
        "in_progress": 0,
        "completed": 1,
        "cancelled": 0,
    }


def test_a_hazard_can_be_filed_against_an_incident(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    incident = _create_incident(client, auth_headers)

    hazard = _create_hazard(client, auth_headers, incident_id=incident["id"])

    assert hazard["incident_id"] == incident["id"]


@pytest.mark.parametrize(
    ("url", "factory"),
    [
        (HAZARDS_URL, _hazard_payload),
        (SOS_URL, _sos_payload),
        (TASKS_URL, _task_payload),
    ],
    ids=("hazards", "sos", "tasks"),
)
def test_a_record_filed_against_an_unknown_incident_is_rejected(
    client: TestClient, auth_headers: dict[str, str], url: str, factory
) -> None:
    """The fix is to upload the incident first, not to guess at the link."""
    response = client.post(
        url, json=factory(incident_id=str(uuid.uuid4())), headers=auth_headers
    )

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "not_found"


def test_a_record_without_an_incident_is_accepted(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    """A hazard seen on the way to a scene predates any incident record."""
    hazard = _create_hazard(client, auth_headers)

    assert hazard["incident_id"] is None


def test_blank_strings_are_stored_as_unrecorded(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    task = _create_task(client, auth_headers, description="   ", location="")

    assert task["description"] is None
    assert task["location"] is None


def test_a_hazard_without_an_observation_time_is_rejected(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    """The backend cannot invent when a responder saw something."""
    payload = _hazard_payload()
    del payload["observed_at"]

    response = client.post(HAZARDS_URL, json=payload, headers=auth_headers)

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


@pytest.mark.parametrize(
    ("url", "factory", "invalid"),
    [
        (INCIDENTS_URL, _incident_payload, {"disaster_type": "METEOR_STRIKE"}),
        (INCIDENTS_URL, _incident_payload, {"status": "CLOSED"}),
        (INCIDENTS_URL, _incident_payload, {"id": "not-a-uuid"}),
        (HAZARDS_URL, _hazard_payload, {"severity": "SLIGHTLY_BAD"}),
        (HAZARDS_URL, _hazard_payload, {"latitude": 120.0}),
        (SOS_URL, _sos_payload, {"priority": "LOW"}),
        (SOS_URL, _sos_payload, {"status": "CLOSED"}),
        (TASKS_URL, _task_payload, {"priority": "URGENT"}),
        (TASKS_URL, _task_payload, {"title": ""}),
    ],
)
def test_invalid_uploads_are_rejected(
    client: TestClient,
    auth_headers: dict[str, str],
    url: str,
    factory,
    invalid: dict[str, object],
) -> None:
    response = client.post(url, json=factory(**invalid), headers=auth_headers)

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


def test_the_responder_roster_returns_the_registered_accounts(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    page = client.get(RESPONDERS_URL, headers=auth_headers).json()

    assert page["total"] == 1
    assert set(page["items"][0]) == {
        "id",
        "email",
        "full_name",
        "role",
        "is_active",
        "created_at",
    }
    assert page["items"][0]["email"] == "rescue@example.com"
    assert page["items"][0]["role"] == "RESCUE_TEAM"
    assert page["items"][0]["is_active"] is True


def test_the_responder_roster_never_exposes_a_password_hash(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    page = client.get(RESPONDERS_URL, headers=auth_headers).json()

    assert "hashed_password" not in page["items"][0]


def test_the_severity_and_priority_scales_are_one_based_and_ordered() -> None:
    """Clients sort on these integers, so the scales are part of the contract."""
    assert [severity.priority for severity in HazardSeverity] == [1, 2, 3, 4]
    assert [priority.priority for priority in TaskPriority] == [1, 2, 3, 4]
    assert [priority.priority for priority in SosPriority] == [1, 2, 3]


def test_there_is_no_low_tier_for_an_sos() -> None:
    """A responder who raises an SOS is never a low priority."""
    assert [priority.value for priority in SosPriority] == ["CRITICAL", "HIGH", "MEDIUM"]
