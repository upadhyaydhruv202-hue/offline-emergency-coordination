"""Database access for :class:`~app.models.user.User`."""

from __future__ import annotations

from sqlalchemy import func, or_, select

from app.models.enums import UserRole
from app.models.user import User
from app.repositories.base import BaseRepository


class UserRepository(BaseRepository[User]):
    model = User

    def get_by_email(self, email: str) -> User | None:
        stmt = select(User).where(func.lower(User.email) == email.strip().lower())
        return self.session.scalars(stmt).first()

    def email_exists(self, email: str) -> bool:
        return self.get_by_email(email) is not None

    def search(
        self,
        *,
        search: str | None = None,
        role: UserRole | None = None,
        is_active: bool | None = None,
        limit: int = 100,
        offset: int = 0,
    ) -> list[User]:
        """The roster, read the way it is read aloud: alphabetically by name.

        Deactivated accounts are included unless asked for otherwise, because
        a commander looking for someone needs to see that they are stood down
        rather than find no record of them at all.
        """
        stmt = (
            self._filtered(search=search, role=role, is_active=is_active)
            .order_by(User.full_name.asc())
            .limit(limit)
            .offset(offset)
        )
        return list(self.session.scalars(stmt))

    def count(
        self,
        *,
        search: str | None = None,
        role: UserRole | None = None,
        is_active: bool | None = None,
    ) -> int:
        stmt = self._filtered(search=search, role=role, is_active=is_active).with_only_columns(
            func.count(User.id)
        )
        return self.session.scalar(stmt) or 0

    def _filtered(
        self,
        *,
        search: str | None,
        role: UserRole | None,
        is_active: bool | None,
    ):
        stmt = select(User)
        if role is not None:
            stmt = stmt.where(User.role == role)
        if is_active is not None:
            stmt = stmt.where(User.is_active.is_(is_active))

        term = (search or "").strip()
        if term:
            pattern = f"%{term.lower()}%"
            stmt = stmt.where(
                or_(
                    func.lower(User.full_name).like(pattern),
                    func.lower(User.email).like(pattern),
                )
            )
        return stmt
