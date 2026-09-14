from __future__ import annotations

from sqlalchemy import func, select

from app.models.audit_event import AuditEvent
from app.repositories.base import BaseRepository


class AuditEventRepository(BaseRepository[AuditEvent]):
    model = AuditEvent

    def recent(self, *, limit: int = 50) -> list[AuditEvent]:
        stmt = select(AuditEvent).order_by(AuditEvent.occurred_at.desc()).limit(limit)
        return list(self.session.scalars(stmt))

    def count(self) -> int:
        return self.session.scalar(select(func.count()).select_from(AuditEvent)) or 0
