"""The victim upload endpoint and the command-centre read model."""

from __future__ import annotations

import uuid

import pytest
from fastapi.testclient import TestClient

from app.models.enums import TriageCategory, VictimStatus

VICTIMS_URL = "/api/v1/victims"


def _payload(**overrides: object) -> dict[str, object]:
    """A record as a handset would upload it: identifiers already minted."""
    body: dict[str, object] = {
        "id": str(uuid.uuid4()),
        "temporary_id": f"V-8C1F-{uuid.uuid4().hex[:4].upper()}",
        "name": "A. Sharma",
        "age": 41,
        "age_group": "ADULT",
        "gender": "FEMALE",
        "injury_type": "Crush injury to left leg",
        "triage_category": "CRITICAL",
        "created_by": "local-session-1",
    }
    body.update(overrides)
    return body


def _register(client: TestClient, headers: dict[str, str], **overrides: object) -> dict:
    response = client.post(VICTIMS_URL, json=_payload(**overrides), headers=headers)
    assert response.status_code == 201, response.text
    return response.json()


def test_upload_keeps_the_identifiers_minted_on_the_device(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    payload = _payload()

    body = client.post(VICTIMS_URL, json=payload, headers=auth_headers).json()

    assert body["id"] == payload["id"]
    assert body["temporary_id"] == payload["temporary_id"]
    assert body["created_by"] == "local-session-1"


def test_priority_is_derived_from_the_triage_category(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    critical = _register(client, auth_headers, triage_category="CRITICAL")
    stable = _register(client, auth_headers, triage_category="STABLE")

    assert critical["priority"] == TriageCategory.CRITICAL.priority
    assert stable["priority"] > critical["priority"]


def test_a_record_with_only_a_triage_category_is_accepted(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    """An unidentified casualty must never be harder to register than a named one."""
    payload = {
        "id": str(uuid.uuid4()),
        "temporary_id": "V-8C1F-001",
        "triage_category": "URGENT",
        "created_by": "local-session-1",
    }

    response = client.post(VICTIMS_URL, json=payload, headers=auth_headers)

    assert response.status_code == 201, response.text
    body = response.json()

    assert body["name"] is None
    assert body["age_group"] == "UNKNOWN"
    assert body["status"] == VictimStatus.REGISTERED.value


def test_blank_strings_are_stored_as_unrecorded(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    body = _register(client, auth_headers, name="   ", injury_type="")

    assert body["name"] is None
    assert body["injury_type"] is None


def test_re_uploading_the_same_id_updates_rather_than_conflicts(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    """A device with a flaky link retries; the retry must be harmless."""
    payload = _payload(triage_category="MODERATE")

    first = client.post(VICTIMS_URL, json=payload, headers=auth_headers)
    payload["triage_category"] = "CRITICAL"
    second = client.post(VICTIMS_URL, json=payload, headers=auth_headers)

    assert first.status_code == 201
    assert second.status_code == 201
    assert second.json()["triage_category"] == "CRITICAL"
    assert client.get(VICTIMS_URL, headers=auth_headers).json()["total"] == 1


def test_reassessment_moves_the_record_up_the_list(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    stable = _register(client, auth_headers, name="Later", triage_category="STABLE")
    _register(client, auth_headers, name="Sooner", triage_category="MODERATE")

    response = client.patch(
        f"{VICTIMS_URL}/{stable['id']}",
        json={"triage_category": "CRITICAL"},
        headers=auth_headers,
    )

    assert response.status_code == 200
    assert response.json()["priority"] == TriageCategory.CRITICAL.priority
    listed = client.get(VICTIMS_URL, headers=auth_headers).json()["items"]
    assert [victim["name"] for victim in listed] == ["Later", "Sooner"]


def test_status_can_be_advanced_to_evacuated(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    victim = _register(client, auth_headers)

    response = client.patch(
        f"{VICTIMS_URL}/{victim['id']}",
        json={"status": "EVACUATED"},
        headers=auth_headers,
    )

    assert response.json()["status"] == "EVACUATED"
    assert client.get(VICTIMS_URL + "/board", headers=auth_headers).json()["evacuated"] == 1


def test_an_update_cannot_rewrite_provenance(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    victim = _register(client, auth_headers)

    response = client.patch(
        f"{VICTIMS_URL}/{victim['id']}",
        json={"created_by": "someone-else", "name": "Corrected Name"},
        headers=auth_headers,
    )

    assert response.json()["created_by"] == "local-session-1"
    assert response.json()["name"] == "Corrected Name"


def test_the_list_is_ordered_most_urgent_first(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    for category in ("STABLE", "CRITICAL", "MODERATE", "URGENT"):
        _register(client, auth_headers, name=category, triage_category=category)

    listed = client.get(VICTIMS_URL, headers=auth_headers).json()["items"]

    assert [victim["name"] for victim in listed] == [
        "CRITICAL",
        "URGENT",
        "MODERATE",
        "STABLE",
    ]


def test_the_board_counts_every_category_including_empty_ones(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    _register(client, auth_headers, triage_category="CRITICAL")
    _register(client, auth_headers, triage_category="CRITICAL")
    _register(client, auth_headers, triage_category="STABLE")

    board = client.get(f"{VICTIMS_URL}/board", headers=auth_headers).json()

    assert board["total"] == 3
    assert board["open_cases"] == 3
    assert board["by_triage"] == {"critical": 2, "urgent": 0, "moderate": 0, "stable": 1}


def test_the_board_ignores_the_active_filter(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    """Filtering to one category must not hide how many criticals are open."""
    _register(client, auth_headers, triage_category="CRITICAL")
    _register(client, auth_headers, triage_category="STABLE")

    page = client.get(VICTIMS_URL, params={"triage": "STABLE"}, headers=auth_headers).json()

    assert page["total"] == 1
    assert page["board"]["by_triage"]["critical"] == 1


@pytest.mark.parametrize(
    ("query", "expected"),
    [
        ({"triage": "CRITICAL"}, ["Critical case"]),
        ({"status": "EVACUATED"}, []),
        ({"search": "meera"}, ["Meera Iyer"]),
        ({"search": "burns"}, ["Critical case"]),
    ],
)
def test_the_list_filters_and_searches(
    client: TestClient,
    auth_headers: dict[str, str],
    query: dict[str, str],
    expected: list[str],
) -> None:
    _register(
        client,
        auth_headers,
        name="Critical case",
        injury_type="Burns to both hands",
        triage_category="CRITICAL",
    )
    _register(client, auth_headers, name="Meera Iyer", triage_category="STABLE")

    listed = client.get(VICTIMS_URL, params=query, headers=auth_headers).json()["items"]

    assert [victim["name"] for victim in listed] == expected


def test_reading_an_unknown_victim_is_a_404(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    response = client.get(f"{VICTIMS_URL}/{uuid.uuid4()}", headers=auth_headers)

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "not_found"


def test_victim_endpoints_require_authentication(client: TestClient) -> None:
    assert client.get(VICTIMS_URL).status_code == 401
    assert client.get(f"{VICTIMS_URL}/board").status_code == 401
    assert client.post(VICTIMS_URL, json=_payload()).status_code == 401


@pytest.mark.parametrize(
    "invalid",
    [
        {"triage_category": "SLIGHTLY_HURT"},
        {"status": "DISCHARGED"},
        {"age": -1},
        {"latitude": 120.0},
        {"id": "not-a-uuid"},
    ],
)
def test_invalid_uploads_are_rejected(
    client: TestClient, auth_headers: dict[str, str], invalid: dict[str, object]
) -> None:
    response = client.post(VICTIMS_URL, json=_payload(**invalid), headers=auth_headers)

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


def test_triage_priority_order_matches_the_declaration_order() -> None:
    ordered = sorted(TriageCategory, key=lambda category: category.priority)

    assert [category.value for category in ordered] == [
        "CRITICAL",
        "URGENT",
        "MODERATE",
        "STABLE",
    ]


def test_closed_statuses_are_the_ones_needing_no_field_resources() -> None:
    closed = {status for status in VictimStatus if status.is_closed}

    assert closed == {VictimStatus.EVACUATED, VictimStatus.DECEASED}
