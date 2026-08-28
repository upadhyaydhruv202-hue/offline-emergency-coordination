"""Application configuration loaded from the environment.

Every deployment-specific value is read from environment variables (or a local
``.env`` file). No credential is ever hard-coded in source.
"""

from __future__ import annotations

import secrets
from functools import lru_cache
from typing import Literal

from pydantic import Field, SecretStr, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

Environment = Literal["development", "test", "staging", "production"]

MIN_JWT_SECRET_LENGTH = 32


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
        case_sensitive=False,
    )

    app_name: str = "Disaster Response Platform API"
    app_version: str = "0.1.0"
    environment: Environment = "development"
    debug: bool = False

    api_v1_prefix: str = "/api/v1"

    host: str = "0.0.0.0"
    port: int = 8000

    # postgresql+psycopg://user:password@host:port/database
    # A SQLite URL may be used for local development without Docker.
    database_url: str = "postgresql+psycopg://drp_app:change-me@localhost:5432/drp"
    database_echo: bool = False

    jwt_secret_key: SecretStr | None = None
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60
    refresh_token_expire_minutes: int = 60 * 24 * 7

    # Comma-separated list, e.g. "http://localhost:5173,http://127.0.0.1:5173"
    cors_origins: str = "http://localhost:5173,http://127.0.0.1:5173"

    # Seed data (used only by `python -m app.db.seed`).
    seed_password: SecretStr | None = None

    log_level: str = Field(default="INFO")

    @model_validator(mode="after")
    def _ensure_jwt_secret(self) -> Settings:
        """Require a usable signing key outside development.

        Development falls back to an ephemeral per-process key so a fresh clone
        boots without configuration, at the cost of invalidating tokens on
        restart. That trade-off is unacceptable anywhere else.

        A blank ``JWT_SECRET_KEY=`` in a .env file arrives as an empty string,
        which PyJWT would otherwise accept far too late in the request cycle.
        """
        provided = self.jwt_secret_key.get_secret_value() if self.jwt_secret_key else ""

        if not provided.strip():
            if self.environment in ("development", "test"):
                object.__setattr__(self, "jwt_secret_key", SecretStr(secrets.token_urlsafe(48)))
                return self
            raise ValueError("JWT_SECRET_KEY must be set when ENVIRONMENT is not development/test")

        if self.environment in ("staging", "production") and len(provided) < MIN_JWT_SECRET_LENGTH:
            raise ValueError(f"JWT_SECRET_KEY must be at least {MIN_JWT_SECRET_LENGTH} characters")

        return self

    @property
    def is_sqlite(self) -> bool:
        return self.database_url.startswith("sqlite")

    @property
    def cors_origin_list(self) -> list[str]:
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]

    @property
    def jwt_key(self) -> str:
        assert self.jwt_secret_key is not None  # guaranteed by the validator
        return self.jwt_secret_key.get_secret_value()


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
