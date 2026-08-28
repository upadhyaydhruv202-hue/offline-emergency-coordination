"""Authentication and role-authorization behaviour."""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.errors import AuthenticationError
from app.core.security import TokenType, create_token, decode_token, hash_password, verify_password
from app.models.enums import UserRole
from app.models.user import User
from app.services.auth_service import AuthService
from tests.conftest import TEST_PASSWORD

LOGIN_URL = "/api/v1/auth/login"


def test_login_returns_tokens_and_profile(client: TestClient, responder: User) -> None:
    response = client.post(LOGIN_URL, json={"email": responder.email, "password": TEST_PASSWORD})

    assert response.status_code == 200
    body = response.json()
    assert body["token_type"] == "bearer"
    assert body["access_token"] and body["refresh_token"]
    assert body["expires_in"] > 0
    assert body["user"]["email"] == responder.email
    assert body["user"]["role"] == UserRole.RESCUE_TEAM.value
    assert "hashed_password" not in body["user"]


def test_login_alias_path_from_specification(client: TestClient, responder: User) -> None:
    response = client.post(
        "/auth/login", json={"email": responder.email, "password": TEST_PASSWORD}
    )

    assert response.status_code == 200


def test_login_rejects_wrong_password(client: TestClient, responder: User) -> None:
    response = client.post(
        LOGIN_URL, json={"email": responder.email, "password": "Wrong-Password-1"}
    )

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "authentication_failed"


def test_login_rejects_unknown_email(client: TestClient) -> None:
    response = client.post(
        LOGIN_URL, json={"email": "ghost@example.com", "password": TEST_PASSWORD}
    )

    assert response.status_code == 401


def test_login_rejects_deactivated_account(
    client: TestClient, session: Session, responder: User
) -> None:
    responder.is_active = False
    session.add(responder)
    session.commit()

    response = client.post(LOGIN_URL, json={"email": responder.email, "password": TEST_PASSWORD})

    assert response.status_code == 401


@pytest.mark.parametrize(
    "payload",
    [
        {"email": "not-an-email", "password": TEST_PASSWORD},
        {"email": "rescue@example.com", "password": "short"},
        {"email": "rescue@example.com"},
        {},
    ],
)
def test_login_validates_input(client: TestClient, payload: dict[str, str]) -> None:
    response = client.post(LOGIN_URL, json=payload)

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


def test_me_requires_a_token(client: TestClient) -> None:
    assert client.get("/api/v1/auth/me").status_code == 401


def test_me_rejects_a_malformed_token(client: TestClient) -> None:
    response = client.get("/api/v1/auth/me", headers={"Authorization": "Bearer not.a.jwt"})

    assert response.status_code == 401


def test_me_rejects_a_refresh_token(client: TestClient, responder: User) -> None:
    refresh = create_token(str(responder.id), responder.role.value, TokenType.REFRESH)

    response = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {refresh}"})

    assert response.status_code == 401


def test_me_returns_the_authenticated_user(client: TestClient, responder: User) -> None:
    login = client.post(LOGIN_URL, json={"email": responder.email, "password": TEST_PASSWORD})
    token = login.json()["access_token"]

    response = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {token}"})

    assert response.status_code == 200
    assert response.json()["id"] == str(responder.id)


def test_refresh_rotates_the_access_token(client: TestClient, responder: User) -> None:
    login = client.post(LOGIN_URL, json={"email": responder.email, "password": TEST_PASSWORD})
    refresh_token = login.json()["refresh_token"]

    response = client.post("/api/v1/auth/refresh", json={"refresh_token": refresh_token})

    assert response.status_code == 200
    assert response.json()["access_token"]


def test_refresh_rejects_an_access_token(client: TestClient, responder: User) -> None:
    login = client.post(LOGIN_URL, json={"email": responder.email, "password": TEST_PASSWORD})
    access_token = login.json()["access_token"]

    response = client.post("/api/v1/auth/refresh", json={"refresh_token": access_token})

    assert response.status_code == 401


def test_passwords_are_hashed_not_stored(session: Session, responder: User) -> None:
    assert responder.hashed_password != TEST_PASSWORD
    assert responder.hashed_password.startswith("$2")
    assert verify_password(TEST_PASSWORD, responder.hashed_password)


def test_hashes_are_salted() -> None:
    assert hash_password(TEST_PASSWORD) != hash_password(TEST_PASSWORD)


def test_duplicate_registration_conflicts(session: Session, responder: User) -> None:
    from app.core.errors import ConflictError
    from app.schemas.user import UserCreate

    with pytest.raises(ConflictError):
        AuthService(session).register(
            UserCreate(
                email=responder.email,
                full_name="Duplicate",
                role=UserRole.VOLUNTEER,
                password=TEST_PASSWORD,
            )
        )


def test_token_carries_subject_and_role(responder: User) -> None:
    token = create_token(str(responder.id), responder.role.value)

    payload = decode_token(token, expected_type=TokenType.ACCESS)

    assert payload["sub"] == str(responder.id)
    assert payload["role"] == UserRole.RESCUE_TEAM.value


def test_tampered_token_is_rejected(responder: User) -> None:
    token = create_token(str(responder.id), responder.role.value)

    with pytest.raises(AuthenticationError):
        decode_token(token[:-2] + ("aa" if not token.endswith("aa") else "bb"))
