"""The role model and the `require_roles` authorization primitive."""

from __future__ import annotations

from fastapi import APIRouter, Depends, FastAPI
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.api.deps import require_roles
from app.core.errors import register_exception_handlers
from app.models.enums import COMMAND_ROLES, FIELD_ROLES, UserRole
from app.schemas.user import UserCreate
from app.services.auth_service import AuthService
from tests.conftest import TEST_PASSWORD

EXPECTED_ROLES = {
    "RESCUE_TEAM",
    "MEDICAL_TEAM",
    "VOLUNTEER",
    "INCIDENT_COMMANDER",
    "ADMIN",
}


def test_all_slice_one_roles_exist() -> None:
    assert {role.value for role in UserRole} == EXPECTED_ROLES


def test_role_groupings_partition_the_roles() -> None:
    assert set(UserRole) == COMMAND_ROLES | FIELD_ROLES
    assert not COMMAND_ROLES & FIELD_ROLES


def _guarded_app() -> FastAPI:
    router = APIRouter()

    @router.get("/command-only")
    def command_only(_=Depends(require_roles(UserRole.INCIDENT_COMMANDER, UserRole.ADMIN))) -> dict[str, bool]:
        return {"ok": True}

    app = FastAPI()
    register_exception_handlers(app)
    app.include_router(router)
    return app


def _token_for(session: Session, role: UserRole) -> str:
    service = AuthService(session)
    user = service.register(
        UserCreate(
            email=f"{role.value.lower()}@example.com",
            full_name=role.label,
            role=role,
            password=TEST_PASSWORD,
        )
    )
    session.commit()
    return service.issue_tokens(user).access_token


def test_permitted_role_is_admitted(session: Session) -> None:
    token = _token_for(session, UserRole.INCIDENT_COMMANDER)

    with TestClient(_guarded_app()) as client:
        response = client.get("/command-only", headers={"Authorization": f"Bearer {token}"})

    assert response.status_code == 200


def test_other_roles_are_refused(session: Session) -> None:
    token = _token_for(session, UserRole.VOLUNTEER)

    with TestClient(_guarded_app()) as client:
        response = client.get("/command-only", headers={"Authorization": f"Bearer {token}"})

    assert response.status_code == 403
    assert response.json()["error"]["code"] == "not_authorized"
