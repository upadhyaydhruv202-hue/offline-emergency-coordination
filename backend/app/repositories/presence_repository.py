from __future__ import annotations

import uuid

from sqlalchemy import select

from app.models.responder_presence import ResponderPresence
from app.repositories.base import BaseRepository


class PresenceRepository(BaseRepository[ResponderPresence]):
    model = ResponderPresence

    def get_by_user(self, user_id: uuid.UUID) -> ResponderPresence | None:
        stmt = select(ResponderPresence).where(ResponderPresence.user_id == user_id)
        return self.session.scalars(stmt).first()

    def list_all(self) -> list[ResponderPresence]:
        return list(self.session.scalars(select(ResponderPresence)))
