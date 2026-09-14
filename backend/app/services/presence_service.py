from __future__ import annotations

import uuid
from datetime import UTC, datetime

from sqlalchemy.orm import Session

from app.core.errors import NotFoundError
from app.models.enums import ResponderStatus
from app.models.responder_presence import ResponderPresence
from app.models.user import User
from app.repositories.presence_repository import PresenceRepository
from app.repositories.user_repository import UserRepository
from app.schemas.presence import PresenceRead, PresenceUpdate, ResponderOperationalRead


class PresenceService:
    def __init__(self, session: Session) -> None:
        self.session = session
        self.presences = PresenceRepository(session)
        self.users = UserRepository(session)

    def upsert(self, user_id: uuid.UUID, payload: PresenceUpdate) -> ResponderPresence:
        user = self.users.get(user_id)
        if user is None:
            raise NotFoundError("No responder with that identifier")
        row = self.presences.get_by_user(user_id)
        now = datetime.now(UTC)
        if row is None:
            row = ResponderPresence(
                user_id=user_id,
                status=payload.status or ResponderStatus.AVAILABLE,
                last_seen_at=now,
            )
            self.presences.add(row)
        for field in payload.model_fields_set:
            setattr(row, field, getattr(payload, field))
        row.last_seen_at = now
        self.session.add(row)
        self.session.commit()
        self.session.refresh(row)
        return row

    def operational_roster(self, users: list[User]) -> list[ResponderOperationalRead]:
        by_user = {row.user_id: row for row in self.presences.list_all()}
        out: list[ResponderOperationalRead] = []
        for user in users:
            presence = by_user.get(user.id)
            base = ResponderOperationalRead.model_validate(user)
            out.append(
                base.model_copy(
                    update={"presence": PresenceRead.model_validate(presence) if presence else None}
                )
            )
        return out
