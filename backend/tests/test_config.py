"""Configuration guard rails."""

from __future__ import annotations

import pytest
from pydantic import ValidationError

from app.core.config import MIN_JWT_SECRET_LENGTH, Settings

STRONG_KEY = "x" * MIN_JWT_SECRET_LENGTH


def _settings(**overrides: object) -> Settings:
    # _env_file=None isolates the test from the developer's local .env.
    return Settings(_env_file=None, **overrides)  # type: ignore[arg-type]


@pytest.mark.parametrize("blank", [None, "", "   "])
def test_development_generates_a_key_when_none_is_supplied(blank: str | None) -> None:
    settings = _settings(environment="development", jwt_secret_key=blank)

    assert settings.jwt_key.strip()


@pytest.mark.parametrize("blank", ["", "   "])
def test_production_refuses_a_blank_key(blank: str) -> None:
    with pytest.raises(ValidationError, match="JWT_SECRET_KEY must be set"):
        _settings(environment="production", jwt_secret_key=blank)


def test_production_refuses_a_short_key() -> None:
    with pytest.raises(ValidationError, match="at least"):
        _settings(environment="production", jwt_secret_key="too-short")


def test_production_accepts_a_strong_key() -> None:
    assert _settings(environment="production", jwt_secret_key=STRONG_KEY).jwt_key == STRONG_KEY


def test_cors_origins_parse_from_a_comma_separated_string() -> None:
    settings = _settings(cors_origins="http://a.example , http://b.example,")

    assert settings.cors_origin_list == ["http://a.example", "http://b.example"]


def test_sqlite_detection_drives_connect_args() -> None:
    assert _settings(database_url="sqlite+pysqlite:///./x.sqlite3").is_sqlite
    assert not _settings(database_url="postgresql+psycopg://u:p@h:5432/d").is_sqlite
