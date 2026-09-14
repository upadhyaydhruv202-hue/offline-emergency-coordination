"""Test fixtures.

The suite runs against a throwaway SQLite file so it needs neither Docker nor
PostgreSQL. Environment variables are set before ``app`` is imported because
settings are read once at import time.
"""

from __future__ import annotations

import os
from collections.abc import Iterator
from pathlib import Path
from tempfile import TemporaryDirectory

import pytest

# ignore_cleanup_errors: on Windows the SQLite file may still be memory-mapped
# by the engine at interpreter shutdown.
_TMPDIR = TemporaryDirectory(ignore_cleanup_errors=True)
_DB_PATH = Path(_TMPDIR.name) / "test.sqlite3"

os.environ.setdefault("ENVIRONMENT", "test")
os.environ.setdefault("DATABASE_URL", f"sqlite+pysqlite:///{_DB_PATH.as_posix()}")
os.environ.setdefault("JWT_SECRET_KEY", "test-only-signing-key-not-used-in-any-deployment")

from fastapi.testclient import TestClient  # noqa: E402
from sqlalchemy.orm import Session  # noqa: E402

from app.db.session import SessionFactory, engine  # noqa: E402
from app.main import create_app  # noqa: E402
from app.models.base import Base  # noqa: E402
from app.models.enums import UserRole  # noqa: E402
from app.models.hazard import Hazard  # noqa: E402
from app.models.incident import Incident  # noqa: E402
from app.models.sos_event import SosEvent  # noqa: E402
from app.models.task import Task  # noqa: E402
from app.models.user import User  # noqa: E402
from app.models.victim import Victim  # noqa: E402
from app.schemas.user import UserCreate  # noqa: E402
from app.services.auth_service import AuthService  # noqa: E402

TEST_PASSWORD = "Correct-Horse-Battery-9"


@pytest.fixture(scope="session", autouse=True)
def _schema() -> Iterator[None]:
    Base.metadata.create_all(engine)
    yield
    Base.metadata.drop_all(engine)
    engine.dispose()


@pytest.fixture
def session() -> Iterator[Session]:
    with SessionFactory() as db:
        yield db


@pytest.fixture(autouse=True)
def _clean_tables(session: Session) -> Iterator[None]:
    yield
    # Children before parents, so the foreign keys to ``incidents`` hold on a
    # backend that enforces them.
    session.query(Hazard).delete()
    session.query(SosEvent).delete()
    session.query(Task).delete()
    session.query(Incident).delete()
    session.query(Victim).delete()
    session.query(User).delete()
    session.commit()


@pytest.fixture
def client() -> Iterator[TestClient]:
    with TestClient(create_app()) as test_client:
        yield test_client


@pytest.fixture
def responder(session: Session) -> User:
    user = AuthService(session).register(
        UserCreate(
            email="rescue@example.com",
            full_name="Test Responder",
            role=UserRole.RESCUE_TEAM,
            password=TEST_PASSWORD,
        )
    )
    session.commit()
    return user


@pytest.fixture
def auth_headers(session: Session, responder: User) -> dict[str, str]:
    token = AuthService(session).issue_tokens(responder).access_token
    return {"Authorization": f"Bearer {token}"}
