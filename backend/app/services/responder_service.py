"""The responder roster.

Read-only. Accounts are created by :mod:`app.services.auth_service`; this
service exists so the command centre can list who is on the platform without
a route reaching for a repository, and so the roster stays a separate concern
from authentication.
"""

from __future__ import annotations

from sqlalchemy.orm import Session

from app.models.enums import UserRole
from app.repositories.user_repository import UserRepository
from app.schemas.responder import ResponderPage
from app.schemas.user import UserRead


class ResponderService:
    def __init__(self, session: Session) -> None:
        self.session = session
        self.users = UserRepository(session)

    def page(
        self,
        *,
        search: str | None = None,
        role: UserRole | None = None,
        is_active: bool | None = None,
        limit: int = 100,
        offset: int = 0,
    ) -> ResponderPage:
        items = self.users.search(
            search=search, role=role, is_active=is_active, limit=limit, offset=offset
        )
        return ResponderPage(
            items=[UserRead.model_validate(user) for user in items],
            total=self.users.count(search=search, role=role, is_active=is_active),
        )
