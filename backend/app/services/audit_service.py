from __future__ import annotations

from datetime import UTC, datetime

from sqlalchemy.orm import Session

from app.models.audit_event import AuditEvent
from app.repositories.audit_event_repository import AuditEventRepository
from app.schemas.audit import AuditEventCreate, AuditEventPage, AuditEventRead


class AuditService:
    def __init__(self, session: Session) -> None:
        self.session = session
        self.events = AuditEventRepository(session)

    def record(self, payload: AuditEventCreate, *, commit: bool = True) -> AuditEvent:
        row = AuditEvent(
            category=payload.category,
            summary=payload.summary,
            severity=payload.severity,
            entity_type=payload.entity_type,
            entity_id=payload.entity_id,
            actor_id=payload.actor_id,
            occurred_at=payload.occurred_at if payload.occurred_at.tzinfo else payload.occurred_at.replace(tzinfo=UTC),
        )
        created = self.events.add(row)
        if commit:
            self.session.commit()
            self.session.refresh(created)
        return created

    def page(self, *, limit: int = 50) -> AuditEventPage:
        items = self.events.recent(limit=limit)
        return AuditEventPage(
            items=[AuditEventRead.model_validate(row) for row in items],
            total=self.events.count(),
        )
