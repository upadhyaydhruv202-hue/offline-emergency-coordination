"""Assemble the command-centre common operational picture from existing tables."""

from __future__ import annotations

from datetime import UTC, datetime

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.enums import (
    FacilityKind,
    HazardStatus,
    HazardType,
    IncidentStatus,
    ResponderStatus,
    SosStatus,
    SyncQueueStatus,
    TriageCategory,
)
from app.models.sync_conflict import SyncConflict
from app.models.sync_operation import SyncOperation
from app.repositories.facility_repository import FacilityRepository
from app.repositories.hazard_repository import HazardRepository
from app.repositories.incident_repository import IncidentRepository
from app.repositories.sos_event_repository import SosEventRepository
from app.repositories.task_repository import TaskRepository
from app.repositories.user_repository import UserRepository
from app.repositories.victim_repository import VictimRepository
from app.schemas.audit import AuditEventRead
from app.schemas.command import CommandAlert, CommandKpis, CommandSnapshot, MapMarker, SyncOperationsSummary
from app.schemas.facility import FacilityRead
from app.schemas.hazard import HazardRead
from app.schemas.incident import IncidentRead
from app.schemas.sos_event import SosEventRead
from app.schemas.sync import SyncConflictRead
from app.schemas.task import TaskRead
from app.schemas.victim import VictimRead
from app.services.audit_service import AuditService
from app.services.facility_service import FacilityService
from app.services.presence_service import PresenceService

LAYERS = (
    "incidents",
    "victims",
    "responders",
    "hazards",
    "roadblocks",
    "hospitals",
    "shelters",
    "resources",
    "sos",
)


class CommandService:
    def __init__(self, session: Session) -> None:
        self.session = session
        self.incidents = IncidentRepository(session)
        self.victims = VictimRepository(session)
        self.hazards = HazardRepository(session)
        self.sos_events = SosEventRepository(session)
        self.tasks = TaskRepository(session)
        self.users = UserRepository(session)
        self.facilities = FacilityRepository(session)
        self.facility_service = FacilityService(session)
        self.presence = PresenceService(session)
        self.audit = AuditService(session)

    def snapshot(self) -> CommandSnapshot:
        incidents = self.incidents.search(limit=200)
        victims = self.victims.search(limit=200)
        hazards = self.hazards.search(limit=200)
        sos = self.sos_events.search(limit=200)
        tasks = self.tasks.search(limit=200)
        users = self.users.search(is_active=True, limit=200)
        facilities = self.facilities.search(limit=200)
        responders = self.presence.operational_roster(users)
        facility_board = self.facility_service.board()
        activity = [AuditEventRead.model_validate(row) for row in self.audit.events.recent(limit=40)]
        conflicts = list(
            self.session.scalars(select(SyncConflict).order_by(SyncConflict.detected_at.desc()).limit(50))
        )
        sync = self._sync_summary(len(conflicts))

        open_hazards = [h for h in hazards if h.status is not HazardStatus.RESOLVED]
        blocked = [
            h
            for h in open_hazards
            if h.type in {HazardType.ROAD_BLOCKED, HazardType.PARTIALLY_ACCESSIBLE}
        ]
        active_sos = [row for row in sos if row.status is not SosStatus.RESOLVED]
        pending_tasks = [row for row in tasks if not row.status.is_closed]
        critical_victims = [row for row in victims if row.triage_category is TriageCategory.CRITICAL]
        on_duty = [
            row
            for row in responders
            if row.presence is None or row.presence.status is not ResponderStatus.OFF_DUTY
        ]

        kpis = CommandKpis(
            active_incidents=sum(1 for row in incidents if row.status is IncidentStatus.ACTIVE),
            critical_victims=len(critical_victims),
            active_responders=len(on_duty),
            active_sos=len(active_sos),
            open_hazards=len(open_hazards),
            blocked_roads=len(blocked),
            hospital_beds_remaining=facility_board.hospital_beds_remaining,
            pending_tasks=len(pending_tasks),
            conflicts=sync.conflicts,
            pending_sync=sync.pending,
        )

        markers = _markers(incidents, victims, hazards, sos, facilities, responders)
        alerts = _alerts(kpis, victims, hazards, active_sos, facilities, sync)

        return CommandSnapshot(
            generated_at=datetime.now(UTC),
            kpis=kpis,
            alerts=alerts,
            incidents=[IncidentRead.model_validate(row) for row in incidents],
            victims=[VictimRead.model_validate(row) for row in victims],
            hazards=[HazardRead.model_validate(row) for row in hazards],
            sos=[SosEventRead.model_validate(row) for row in sos],
            tasks=[TaskRead.model_validate(row) for row in tasks],
            responders=responders,
            facilities=[FacilityRead.model_validate(row) for row in facilities],
            facility_board=facility_board,
            activity=activity,
            sync=sync,
            conflicts=[SyncConflictRead.model_validate(row) for row in conflicts],
            markers=markers,
            layers=list(LAYERS),
            facility_kinds=list(FacilityKind),
        )

    def _sync_summary(self, conflict_count: int) -> SyncOperationsSummary:
        def _count(value: SyncQueueStatus) -> int:
            return (
                self.session.scalar(
                    select(func.count()).select_from(SyncOperation).where(SyncOperation.queue_status == value)
                )
                or 0
            )

        devices = self.session.scalar(select(func.count(func.distinct(SyncOperation.device_id)))) or 0
        last = self.session.scalar(select(func.max(SyncOperation.updated_at)))
        resolved = (
            self.session.scalar(
                select(func.count()).select_from(SyncConflict).where(SyncConflict.resolved_at.is_not(None))
            )
            or 0
        )
        return SyncOperationsSummary(
            pending=_count(SyncQueueStatus.PENDING),
            in_flight=_count(SyncQueueStatus.IN_FLIGHT),
            acknowledged=_count(SyncQueueStatus.ACKNOWLEDGED),
            failed=_count(SyncQueueStatus.FAILED),
            conflicts=conflict_count,
            resolved_conflicts=resolved,
            distinct_devices=devices,
            last_push_at=last,
        )


def _alerts(kpis, victims, hazards, active_sos, facilities, sync) -> list[CommandAlert]:
    alerts: list[CommandAlert] = []
    if kpis.critical_victims:
        alerts.append(
            CommandAlert(
                code="CRITICAL_VICTIM",
                title="Critical victims",
                detail=f"{kpis.critical_victims} casualty records triaged CRITICAL",
                severity="CRITICAL",
                href="/victims",
            )
        )
    if kpis.active_sos:
        alerts.append(
            CommandAlert(
                code="ACTIVE_SOS",
                title="Active SOS",
                detail=f"{kpis.active_sos} open distress calls",
                severity="CRITICAL",
                href="/sos",
            )
        )
    blocked = [h for h in hazards if h.type is HazardType.ROAD_BLOCKED and h.status is not HazardStatus.RESOLVED]
    if blocked:
        alerts.append(
            CommandAlert(
                code="ROAD_BLOCKED",
                title="Road blocked",
                detail=blocked[0].description or blocked[0].hazard_code,
                severity="HIGH",
                href="/hazards",
            )
        )
    critical_hazards = [
        h for h in hazards if h.severity.value == "CRITICAL" and h.status is not HazardStatus.RESOLVED
    ]
    if critical_hazards:
        alerts.append(
            CommandAlert(
                code="HIGH_SEVERITY_HAZARD",
                title="Critical hazard",
                detail=critical_hazards[0].description or critical_hazards[0].hazard_code,
                severity="CRITICAL",
                href="/hazards",
            )
        )
    for facility in facilities:
        if facility.kind is FacilityKind.HOSPITAL and facility.capacity_total:
            remaining = facility.remaining
            if remaining / facility.capacity_total <= 0.2:
                alerts.append(
                    CommandAlert(
                        code="HOSPITAL_CAPACITY_LOW",
                        title="Hospital capacity low",
                        detail=f"{facility.name}: {remaining} beds remaining",
                        severity="HIGH",
                        href="/hospitals",
                    )
                )
                break
    if sync.conflicts:
        alerts.append(
            CommandAlert(
                code="SYNC_CONFLICT",
                title="Sync conflict",
                detail=f"{sync.conflicts} recorded · SIMULATED SYNC",
                severity="HIGH",
                href="/sync/conflicts",
            )
        )
    return alerts[:8]


def _markers(incidents, victims, hazards, sos, facilities, responders) -> list[MapMarker]:
    markers: list[MapMarker] = []
    for row in incidents:
        if row.latitude is None or row.longitude is None:
            continue
        markers.append(
            MapMarker(
                id=str(row.id),
                layer="incidents",
                label=row.title,
                latitude=row.latitude,
                longitude=row.longitude,
                status=row.status.value,
                subtitle=row.assigned_zone,
            )
        )
    for row in victims:
        if row.latitude is None or row.longitude is None:
            continue
        markers.append(
            MapMarker(
                id=str(row.id),
                layer="victims",
                label=row.temporary_id,
                latitude=row.latitude,
                longitude=row.longitude,
                severity=row.triage_category.value,
                status=row.status.value,
                subtitle=row.name,
            )
        )
    for row in hazards:
        if row.latitude is None or row.longitude is None:
            continue
        road = row.type in {HazardType.ROAD_BLOCKED, HazardType.PARTIALLY_ACCESSIBLE}
        markers.append(
            MapMarker(
                id=str(row.id),
                layer="roadblocks" if road else "hazards",
                label=row.hazard_code,
                latitude=row.latitude,
                longitude=row.longitude,
                kind=row.type.value,
                severity=row.severity.value,
                status=row.status.value,
                subtitle=row.description,
            )
        )
    for row in sos:
        if row.latitude is None or row.longitude is None:
            continue
        markers.append(
            MapMarker(
                id=str(row.id),
                layer="sos",
                label=row.sos_code,
                latitude=row.latitude,
                longitude=row.longitude,
                severity=row.priority.value,
                status=row.status.value,
                subtitle=row.message,
            )
        )
    for row in facilities:
        if row.latitude is None or row.longitude is None:
            continue
        layer = {
            FacilityKind.HOSPITAL: "hospitals",
            FacilityKind.SHELTER: "shelters",
            FacilityKind.RESOURCE_CACHE: "resources",
        }[row.kind]
        markers.append(
            MapMarker(
                id=str(row.id),
                layer=layer,
                label=row.name,
                latitude=row.latitude,
                longitude=row.longitude,
                kind=row.kind.value,
                status=row.status.value,
                subtitle=f"{row.remaining} remaining of {row.capacity_total}",
            )
        )
    for row in responders:
        presence = row.presence
        if presence is None or presence.latitude is None or presence.longitude is None:
            continue
        markers.append(
            MapMarker(
                id=str(row.id),
                layer="responders",
                label=row.full_name,
                latitude=presence.latitude,
                longitude=presence.longitude,
                status=presence.status.value,
                kind=row.role.value,
                subtitle=presence.device_id,
            )
        )
    return markers
