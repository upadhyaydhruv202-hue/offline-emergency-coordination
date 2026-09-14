"""Common operational picture assembled from existing domain tables."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel

from app.models.enums import FacilityKind
from app.schemas.audit import AuditEventRead
from app.schemas.facility import FacilityBoard, FacilityRead
from app.schemas.hazard import HazardRead
from app.schemas.incident import IncidentRead
from app.schemas.presence import ResponderOperationalRead
from app.schemas.sos_event import SosEventRead
from app.schemas.sync import SyncConflictRead
from app.schemas.task import TaskRead
from app.schemas.victim import VictimRead


class CommandKpis(BaseModel):
    active_incidents: int = 0
    critical_victims: int = 0
    active_responders: int = 0
    active_sos: int = 0
    open_hazards: int = 0
    blocked_roads: int = 0
    hospital_beds_remaining: int = 0
    pending_tasks: int = 0
    conflicts: int = 0
    pending_sync: int = 0


class CommandAlert(BaseModel):
    code: str
    title: str
    detail: str
    severity: str
    href: str


class MapMarker(BaseModel):
    """Stable marker contract so Slice 6 can add risk layers without replacing the map."""

    id: str
    layer: str
    label: str
    latitude: float
    longitude: float
    status: str | None = None
    severity: str | None = None
    kind: str | None = None
    subtitle: str | None = None


class SyncOperationsSummary(BaseModel):
    pending: int = 0
    in_flight: int = 0
    acknowledged: int = 0
    failed: int = 0
    conflicts: int = 0
    resolved_conflicts: int = 0
    distinct_devices: int = 0
    last_push_at: datetime | None = None
    transport: str = "SIMULATED SYNC"
    note: str = "Peer ingest only. This is not live mesh networking."


class CommandSnapshot(BaseModel):
    generated_at: datetime
    kpis: CommandKpis
    alerts: list[CommandAlert]
    incidents: list[IncidentRead]
    victims: list[VictimRead]
    hazards: list[HazardRead]
    sos: list[SosEventRead]
    tasks: list[TaskRead]
    responders: list[ResponderOperationalRead]
    facilities: list[FacilityRead]
    facility_board: FacilityBoard
    activity: list[AuditEventRead]
    sync: SyncOperationsSummary
    conflicts: list[SyncConflictRead]
    markers: list[MapMarker]
    layers: list[str]
    facility_kinds: list[FacilityKind]
