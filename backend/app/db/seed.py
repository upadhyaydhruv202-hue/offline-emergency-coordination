"""Create the demo responder accounts.

Run with::

    python -m app.db.seed
    python -m app.db.seed --victims     # also insert demo casualties
    python -m app.db.seed --field-ops   # also insert demo incidents/hazards/SOS/tasks
    python -m app.db.seed --sync-demo   # ingest the Road R-12 peer-conflict pair

Credentials are never stored in source. The password comes from ``SEED_PASSWORD``;
if it is absent, a strong one is generated and printed once so the operator can
record it.
"""

from __future__ import annotations

import json
import secrets
import sys
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

from sqlalchemy.orm import Session

from app.core.config import settings
from app.db.session import SessionFactory
from app.models.enums import (
    AgeGroup,
    AuditSeverity,
    DisasterType,
    FacilityKind,
    FacilityStatus,
    Gender,
    HazardSeverity,
    HazardStatus,
    HazardType,
    IncidentStatus,
    ResponderStatus,
    SosPriority,
    SosStatus,
    SyncEntityType,
    SyncOperationType,
    SyncQueueStatus,
    ConflictResolutionKind,
    TaskPriority,
    TaskStatus,
    TriageCategory,
    UserRole,
    VictimStatus,
)
from app.models.audit_event import AuditEvent
from app.models.facility import Facility
from app.models.responder_presence import ResponderPresence
from app.models.sync_conflict import SyncConflict
from app.models.sync_operation import SyncOperation
from app.repositories.hazard_repository import HazardRepository
from app.repositories.incident_repository import IncidentRepository
from app.repositories.sos_event_repository import SosEventRepository
from app.repositories.task_repository import TaskRepository
from app.repositories.user_repository import UserRepository
from app.repositories.victim_repository import VictimRepository
from app.schemas.hazard import HazardCreate
from app.schemas.incident import IncidentCreate
from app.schemas.sos_event import SosEventCreate
from app.schemas.task import TaskCreate
from app.schemas.user import UserCreate
from app.schemas.victim import VictimCreate
from app.services.auth_service import AuthService
from app.services.hazard_service import HazardService
from app.services.incident_service import IncidentService
from app.services.sos_service import SosService
from app.services.task_service import TaskService
from app.services.victim_service import VictimService


@dataclass(frozen=True)
class SeedPersona:
    email: str
    full_name: str
    role: UserRole


# RFC 2606 reserves the `.example` TLD, so these can never resolve to a real
# mailbox by accident.
PERSONAS: tuple[SeedPersona, ...] = (
    SeedPersona("commander@drp.example", "A. Rathore", UserRole.INCIDENT_COMMANDER),
    SeedPersona("rescue@drp.example", "S. Menon", UserRole.RESCUE_TEAM),
    SeedPersona("medical@drp.example", "Dr. P. Iyer", UserRole.MEDICAL_TEAM),
    SeedPersona("volunteer@drp.example", "K. Sharma", UserRole.VOLUNTEER),
    SeedPersona("admin@drp.example", "Platform Admin", UserRole.ADMIN),
    SeedPersona("alpha@drp.example", "Responder Alpha", UserRole.RESCUE_TEAM),
    SeedPersona("bravo@drp.example", "Responder Bravo", UserRole.RESCUE_TEAM),
)


def resolve_seed_password() -> tuple[str, bool]:
    """Return ``(password, was_generated)``."""
    if settings.seed_password is not None:
        return settings.seed_password.get_secret_value(), False
    return secrets.token_urlsafe(16), True


def seed_users(session: Session, password: str) -> tuple[int, int]:
    """Insert any missing personas. Returns ``(created, skipped)``."""
    repository = UserRepository(session)
    service = AuthService(session)
    created = skipped = 0

    for persona in PERSONAS:
        if repository.email_exists(persona.email):
            skipped += 1
            continue
        service.register(
            UserCreate(
                email=persona.email,
                full_name=persona.full_name,
                role=persona.role,
                password=password,
            )
        )
        created += 1

    return created, skipped


@dataclass(frozen=True)
class SeedCasualty:
    temporary_id: str
    name: str | None
    age: int | None
    triage: TriageCategory
    status: VictimStatus
    injury: str
    lat_offset: float
    lng_offset: float


# `SEED` in the tag rather than a device code, so a demo record is never
# mistaken for one a responder actually registered in the field.
CASUALTIES: tuple[SeedCasualty, ...] = (
    SeedCasualty(
        "V-SEED-001",
        "A. Sharma",
        41,
        TriageCategory.CRITICAL,
        VictimStatus.AWAITING_EVACUATION,
        "Crush injury to left leg",
        0.004,
        -0.003,
    ),
    SeedCasualty(
        "V-SEED-002",
        None,
        None,
        TriageCategory.CRITICAL,
        VictimStatus.UNDER_TREATMENT,
        "Head trauma, unresponsive",
        0.006,
        0.002,
    ),
    SeedCasualty(
        "V-SEED-003",
        "R. Verma",
        58,
        TriageCategory.URGENT,
        VictimStatus.REGISTERED,
        "Open fracture, right forearm",
        -0.003,
        0.005,
    ),
    SeedCasualty(
        "V-SEED-004",
        "M. Iyer",
        9,
        TriageCategory.MODERATE,
        VictimStatus.REGISTERED,
        "Lacerations, smoke inhalation",
        -0.005,
        -0.004,
    ),
    SeedCasualty(
        "V-SEED-005",
        "K. Nair",
        33,
        TriageCategory.STABLE,
        VictimStatus.EVACUATED,
        "Minor abrasions",
        0.001,
        0.007,
    ),
)


def seed_victims(session: Session) -> tuple[int, int]:
    """Insert demo casualties for the command centre. Returns ``(created, skipped)``.

    Opt-in, because the mobile app does not upload yet: without this the
    Victims page is legitimately empty, and that emptiness is the honest state
    of the system rather than a fault to paper over.
    """
    repository = VictimRepository(session)
    service = VictimService(session)
    created = skipped = 0

    for casualty in CASUALTIES:
        if repository.get_by_temporary_id(casualty.temporary_id) is not None:
            skipped += 1
            continue
        service.register(
            VictimCreate(
                id=uuid.uuid4(),
                temporary_id=casualty.temporary_id,
                name=casualty.name,
                age=casualty.age,
                age_group=AgeGroup.CHILD if (casualty.age or 99) < 13 else AgeGroup.ADULT,
                gender=Gender.UNKNOWN,
                injury_type=casualty.injury,
                triage_category=casualty.triage,
                status=casualty.status,
                created_by="seed",
                latitude=_ZONE_LATITUDE + casualty.lat_offset,
                longitude=_ZONE_LONGITUDE + casualty.lng_offset,
            )
        )
        created += 1

    return created, skipped


_ZONE_LATITUDE = 23.0225
_ZONE_LONGITUDE = 72.5714
_SEED_AUTHOR = "seed"


@dataclass(frozen=True)
class SeedIncident:
    incident_code: str
    title: str
    disaster_type: DisasterType
    status: IncidentStatus
    assigned_zone: str | None
    description: str


INCIDENTS: tuple[SeedIncident, ...] = (
    SeedIncident(
        "INC-SEED-001",
        "Ahmedabad Earthquake Response",
        DisasterType.EARTHQUAKE,
        IncidentStatus.ACTIVE,
        "Ahmedabad Zone 04",
        "Magnitude 6.2. Multiple collapsed structures across four wards.",
    ),
    SeedIncident(
        "INC-SEED-002",
        "Sabarmati Riverfront Flooding",
        DisasterType.FLOOD,
        IncidentStatus.PAUSED,
        "Riverfront West",
        "Response suspended overnight; water level being monitored hourly.",
    ),
)


@dataclass(frozen=True)
class SeedHazard:
    hazard_code: str
    hazard_type: HazardType
    severity: HazardSeverity
    status: HazardStatus
    description: str
    minutes_ago: int


HAZARDS: tuple[SeedHazard, ...] = (
    SeedHazard(
        "HZ-SEED-001",
        HazardType.BUILDING_DAMAGE,
        HazardSeverity.CRITICAL,
        HazardStatus.VERIFIED,
        "Four-storey block leaning over the access road; do not approach on foot.",
        25,
    ),
    SeedHazard(
        "HZ-SEED-002",
        HazardType.ELECTRICAL_HAZARD,
        HazardSeverity.HIGH,
        HazardStatus.REPORTED,
        "Live cable down across the junction, standing water beneath it.",
        70,
    ),
    SeedHazard(
        "HZ-SEED-003",
        HazardType.ROAD_BLOCKED,
        HazardSeverity.MEDIUM,
        HazardStatus.REPORTED,
        "Rubble blocking both lanes; passable on foot only.",
        140,
    ),
    SeedHazard(
        "HZ-SEED-004",
        HazardType.SMOKE,
        HazardSeverity.LOW,
        HazardStatus.RESOLVED,
        "Smoke from a generator fire, extinguished.",
        300,
    ),
)


@dataclass(frozen=True)
class SeedSosEvent:
    sos_code: str
    priority: SosPriority
    status: SosStatus
    message: str
    minutes_ago: int


SOS_EVENTS: tuple[SeedSosEvent, ...] = (
    SeedSosEvent(
        "SOS-SEED-001",
        SosPriority.CRITICAL,
        SosStatus.CREATED,
        "Team of two trapped on the second floor, structure still shifting.",
        8,
    ),
    SeedSosEvent(
        "SOS-SEED-002",
        SosPriority.HIGH,
        SosStatus.ACKNOWLEDGED,
        "Out of water and stretchers, casualties waiting at the triage point.",
        45,
    ),
    SeedSosEvent(
        "SOS-SEED-003",
        SosPriority.MEDIUM,
        SosStatus.RESOLVED,
        "Lost contact with the ward team; re-established on the backup channel.",
        180,
    ),
)


@dataclass(frozen=True)
class SeedTask:
    task_code: str
    title: str
    priority: TaskPriority
    status: TaskStatus
    assigned_to: str | None
    location: str


TASKS: tuple[SeedTask, ...] = (
    SeedTask(
        "TASK-SEED-001",
        "Search collapsed block, sector 7",
        TaskPriority.CRITICAL,
        TaskStatus.IN_PROGRESS,
        "rescue-team-1",
        "Sector 7, behind the municipal school",
    ),
    SeedTask(
        "TASK-SEED-002",
        "Set up triage point at the community hall",
        TaskPriority.HIGH,
        TaskStatus.ACCEPTED,
        "medical-team-2",
        "Community hall, Zone 04",
    ),
    SeedTask(
        "TASK-SEED-003",
        "Clear rubble from the northern access road",
        TaskPriority.HIGH,
        TaskStatus.PENDING,
        None,
        "Northern access road",
    ),
    SeedTask(
        "TASK-SEED-004",
        "Distribute water at the relief camp",
        TaskPriority.MEDIUM,
        TaskStatus.COMPLETED,
        "volunteer-group-3",
        "Relief camp, ward 12",
    ),
    SeedTask(
        "TASK-SEED-005",
        "Door-to-door welfare check, ward 9",
        TaskPriority.LOW,
        TaskStatus.CANCELLED,
        None,
        "Ward 9",
    ),
)


def seed_field_operations(session: Session) -> tuple[int, int]:
    """Insert the demo incident, hazard, SOS and task set.

    Returns ``(created, skipped)`` across all four tables. Opt-in for the same
    reason as :func:`seed_victims`: the mobile app does not upload yet, so an
    empty command centre is the honest state of the system rather than a fault
    to paper over - but a demo needs something on the screen.

    The hazards, SOS events and tasks are all filed against ``INC-SEED-001``
    so the web command centre can exercise incident-scoped views.
    """
    incidents = IncidentRepository(session)
    hazards = HazardRepository(session)
    sos_events = SosEventRepository(session)
    tasks = TaskRepository(session)

    incident_service = IncidentService(session)
    hazard_service = HazardService(session)
    sos_service = SosService(session)
    task_service = TaskService(session)

    created = skipped = 0
    now = datetime.now(UTC)

    for incident in INCIDENTS:
        if incidents.get_by_code(incident.incident_code) is not None:
            skipped += 1
            continue
        incident_service.register(
            IncidentCreate(
                id=uuid.uuid4(),
                incident_code=incident.incident_code,
                title=incident.title,
                disaster_type=incident.disaster_type,
                description=incident.description,
                status=incident.status,
                assigned_zone=incident.assigned_zone,
                latitude=_ZONE_LATITUDE,
                longitude=_ZONE_LONGITUDE,
                created_by=_SEED_AUTHOR,
            )
        )
        created += 1

    primary = incidents.get_by_code(INCIDENTS[0].incident_code)
    incident_id = primary.id if primary is not None else None

    for index, hazard in enumerate(HAZARDS):
        if hazards.get_by_code(hazard.hazard_code) is not None:
            skipped += 1
            continue
        hazard_service.register(
            HazardCreate(
                id=uuid.uuid4(),
                hazard_code=hazard.hazard_code,
                incident_id=incident_id,
                reported_by=_SEED_AUTHOR,
                type=hazard.hazard_type,
                severity=hazard.severity,
                description=hazard.description,
                latitude=_ZONE_LATITUDE + 0.002 * (index + 1),
                longitude=_ZONE_LONGITUDE - 0.002 * (index + 1),
                observed_at=now - timedelta(minutes=hazard.minutes_ago),
                status=hazard.status,
            )
        )
        created += 1

    for index, sos_event in enumerate(SOS_EVENTS):
        if sos_events.get_by_code(sos_event.sos_code) is not None:
            skipped += 1
            continue
        sos_service.register(
            SosEventCreate(
                id=uuid.uuid4(),
                sos_code=sos_event.sos_code,
                incident_id=incident_id,
                created_by=_SEED_AUTHOR,
                latitude=_ZONE_LATITUDE - 0.003 * (index + 1),
                longitude=_ZONE_LONGITUDE + 0.003 * (index + 1),
                raised_at=now - timedelta(minutes=sos_event.minutes_ago),
                priority=sos_event.priority,
                message=sos_event.message,
                status=sos_event.status,
            )
        )
        created += 1

    for task in TASKS:
        if tasks.get_by_code(task.task_code) is not None:
            skipped += 1
            continue
        task_service.register(
            TaskCreate(
                id=uuid.uuid4(),
                task_code=task.task_code,
                incident_id=incident_id,
                assigned_to=task.assigned_to,
                title=task.title,
                priority=task.priority,
                status=task.status,
                location=task.location,
            )
        )
        created += 1

    return created, skipped


def seed_sync_demo(session: Session) -> tuple[int, int]:
    """Two peer operations on Road R-12 plus the recorded conflict."""
    entity_id = "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeee0012"
    existing = session.query(SyncOperation).filter(SyncOperation.entity_id == entity_id).count()
    if existing:
        return 0, existing

    now = datetime.now(UTC)
    alpha_id = uuid.UUID("aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeee00a1")
    bravo_id = uuid.UUID("aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeee00b1")
    session.add(
        SyncOperation(
            id=alpha_id,
            operation_id=alpha_id,
            device_id="DRP-ALPHA001",
            actor_id="responder-alpha",
            entity_type=SyncEntityType.HAZARD,
            entity_id=entity_id,
            operation_type=SyncOperationType.UPDATE,
            payload_json=json.dumps({"type": "ROAD_BLOCKED", "severity": "HIGH", "description": "Road R-12"}),
            queue_status=SyncQueueStatus.ACKNOWLEDGED,
            version=2,
            logical_timestamp=2,
            parent_version=1,
        )
    )
    session.add(
        SyncOperation(
            id=bravo_id,
            operation_id=bravo_id,
            device_id="DRP-BRAVO001",
            actor_id="responder-bravo",
            entity_type=SyncEntityType.HAZARD,
            entity_id=entity_id,
            operation_type=SyncOperationType.UPDATE,
            payload_json=json.dumps(
                {"type": "PARTIALLY_ACCESSIBLE", "severity": "MEDIUM", "description": "Road R-12"}
            ),
            queue_status=SyncQueueStatus.ACKNOWLEDGED,
            version=2,
            logical_timestamp=2,
            parent_version=1,
        )
    )
    session.add(
        SyncConflict(
            entity_type=SyncEntityType.HAZARD,
            entity_id=entity_id,
            operation_a_id=alpha_id,
            operation_b_id=bravo_id,
            detected_at=now,
            resolution=ConflictResolutionKind.DEVICE_TIE_BREAK,
            winner_operation_id=bravo_id,
            loser_operation_id=alpha_id,
            reason="Equal logical timestamps; device id tie-break (DRP-BRAVO001 > DRP-ALPHA001).",
            resolved_at=now,
        )
    )
    return 2, 0


ROAD_R12_ID = uuid.UUID("aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeee0012")


def seed_command_center(session: Session) -> tuple[int, int]:
    """Hospitals, shelters, Road R-12, responder positions and the COP feed."""
    from app.repositories.user_repository import UserRepository
    from app.repositories.victim_repository import VictimRepository

    created = skipped = 0
    now = datetime.now(UTC)
    incidents = IncidentRepository(session)
    hazards = HazardRepository(session)
    victims = VictimRepository(session)
    primary = incidents.get_by_code("INC-SEED-001")
    incident_id = primary.id if primary is not None else None

    if hazards.get_by_code("HZ-R12") is None:
        HazardService(session).register(
            HazardCreate(
                id=ROAD_R12_ID,
                hazard_code="HZ-R12",
                incident_id=incident_id,
                reported_by="DRP-BRAVO001",
                type=HazardType.PARTIALLY_ACCESSIBLE,
                severity=HazardSeverity.MEDIUM,
                description="Road R-12 — converged shared state after SIMULATED SYNC",
                latitude=_ZONE_LATITUDE + 0.008,
                longitude=_ZONE_LONGITUDE + 0.006,
                observed_at=now - timedelta(minutes=12),
                status=HazardStatus.VERIFIED,
            )
        )
        created += 1
    else:
        skipped += 1

    for casualty in CASUALTIES:
        row = victims.get_by_temporary_id(casualty.temporary_id)
        if row is None:
            continue
        if row.latitude is None:
            row.latitude = _ZONE_LATITUDE + casualty.lat_offset
            row.longitude = _ZONE_LONGITUDE + casualty.lng_offset
            session.add(row)
            created += 1

    facilities = (
        Facility(
            id=uuid.UUID("aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeee0a01"),
            facility_code="HSP-SEED-001",
            kind=FacilityKind.HOSPITAL,
            name="Civil Hospital Ahmedabad",
            status=FacilityStatus.LIMITED,
            incident_id=incident_id,
            latitude=_ZONE_LATITUDE + 0.012,
            longitude=_ZONE_LONGITUDE - 0.008,
            capacity_total=120,
            occupancy=98,
            emergency_available=True,
            notes="Emergency wing open. ICU near capacity.",
        ),
        Facility(
            id=uuid.UUID("aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeee0a02"),
            facility_code="SHL-SEED-001",
            kind=FacilityKind.SHELTER,
            name="Zone 04 Community Shelter",
            status=FacilityStatus.OPEN,
            incident_id=incident_id,
            latitude=_ZONE_LATITUDE - 0.009,
            longitude=_ZONE_LONGITUDE + 0.011,
            capacity_total=400,
            occupancy=210,
            emergency_available=False,
            notes="Water and blankets on site.",
        ),
        Facility(
            id=uuid.UUID("aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeee0a03"),
            facility_code="RES-SEED-001",
            kind=FacilityKind.RESOURCE_CACHE,
            name="Ward 12 Staging Cache",
            status=FacilityStatus.OPEN,
            incident_id=incident_id,
            latitude=_ZONE_LATITUDE + 0.002,
            longitude=_ZONE_LONGITUDE - 0.012,
            capacity_total=80,
            occupancy=35,
            emergency_available=False,
            notes="Stretchers and drinking water. SIMULATED stock figure.",
        ),
    )
    for facility in facilities:
        existing = session.get(Facility, facility.id)
        if existing is not None:
            skipped += 1
            continue
        session.add(facility)
        created += 1

    users = UserRepository(session)
    presence_specs = (
        ("alpha@drp.example", ResponderStatus.ON_MISSION, 0.005, -0.002, "DRP-ALPHA001", "Search collapsed block"),
        ("bravo@drp.example", ResponderStatus.EN_ROUTE, -0.004, 0.006, "DRP-BRAVO001", "Road R-12 survey"),
        ("rescue@drp.example", ResponderStatus.AVAILABLE, 0.001, 0.001, "DRP-RESCUE01", None),
        ("medical@drp.example", ResponderStatus.ON_MISSION, 0.007, 0.004, "DRP-MEDICAL1", "Triage point"),
        ("volunteer@drp.example", ResponderStatus.OFF_DUTY, None, None, None, None),
    )
    for email, status, lat_off, lng_off, device_id, task in presence_specs:
        user = users.get_by_email(email)
        if user is None:
            skipped += 1
            continue
        existing = session.query(ResponderPresence).filter(ResponderPresence.user_id == user.id).first()
        if existing is not None:
            skipped += 1
            continue
        session.add(
            ResponderPresence(
                user_id=user.id,
                status=status,
                latitude=None if lat_off is None else _ZONE_LATITUDE + lat_off,
                longitude=None if lng_off is None else _ZONE_LONGITUDE + lng_off,
                last_seen_at=now - timedelta(minutes=4),
                device_id=device_id,
                assigned_incident_id=incident_id,
                assigned_task=task,
            )
        )
        created += 1

    feed = (
        ("VICTIM", "Victim V-SEED-001 triage recorded as CRITICAL", AuditSeverity.CRITICAL, "VICTIM"),
        ("HAZARD", "Road R-12 reported BLOCKED by Device A (SIMULATED SYNC)", AuditSeverity.HIGH, "HAZARD"),
        ("RESPONDER", "Responder Alpha assigned to Zone 04", AuditSeverity.INFO, "RESPONDER"),
        ("SOS", "SOS alert received from trapped team SOS-SEED-001", AuditSeverity.CRITICAL, "SOS"),
        ("HAZARD", "Hazard HZ-SEED-001 updated: building damage verified", AuditSeverity.HIGH, "HAZARD"),
        ("SYNC", "Sync conflict detected for Road R-12", AuditSeverity.HIGH, "HAZARD"),
        ("SYNC", "Conflict resolved using deterministic device tie-break", AuditSeverity.INFO, "HAZARD"),
        ("SYNC", "Entities converged successfully — SIMULATED SYNC", AuditSeverity.INFO, "HAZARD"),
    )
    existing_feed = session.query(AuditEvent).count()
    if existing_feed:
        skipped += existing_feed
    else:
        for index, (category, summary, severity, entity_type) in enumerate(feed):
            session.add(
                AuditEvent(
                    category=category,
                    summary=summary,
                    severity=severity,
                    entity_type=entity_type,
                    entity_id=str(ROAD_R12_ID) if "R-12" in summary else None,
                    actor_id="seed",
                    occurred_at=now - timedelta(minutes=40 - index * 4),
                )
            )
            created += 1

    return created, skipped


def main() -> int:
    password, generated = resolve_seed_password()
    flags = sys.argv[1:]
    with_command_center = "--command-center" in flags
    with_victims = "--victims" in flags or with_command_center
    with_field_ops = "--field-ops" in flags or with_command_center
    with_sync_demo = "--sync-demo" in flags or with_command_center

    with SessionFactory() as session:
        created, skipped = seed_users(session, password)
        session.commit()

        if with_victims:
            victims_created, victims_skipped = seed_victims(session)
            session.commit()

        if with_field_ops:
            field_ops_created, field_ops_skipped = seed_field_operations(session)
            session.commit()

        if with_sync_demo:
            sync_created, sync_skipped = seed_sync_demo(session)
            session.commit()

        command_created = command_skipped = 0
        if with_command_center:
            command_created, command_skipped = seed_command_center(session)
            session.commit()

    print(f"Seed complete: {created} created, {skipped} already present.")
    for persona in PERSONAS:
        print(f"  {persona.role.value:<20} {persona.email}")

    if with_victims:
        print(
            f"\nDemo casualties: {victims_created} created, "
            f"{victims_skipped} already present. Tagged V-SEED-*."
        )

    if with_field_ops:
        print(
            f"\nDemo field operations: {field_ops_created} created, "
            f"{field_ops_skipped} already present. "
            "Tagged INC-SEED-*, HZ-SEED-*, SOS-SEED-* and TASK-SEED-*."
        )

    if with_sync_demo:
        print(
            f"\nDemo sync ingest: {sync_created} operations created, "
            f"{sync_skipped} already present. Road R-12 conflict is labelled SIMULATED."
        )

    if with_command_center:
        print(
            f"\nCommand centre COP: {command_created} created, "
            f"{command_skipped} already present. Road R-12, hospitals and shelters included."
        )

    if generated:
        print("\nSEED_PASSWORD was not set. Generated password for every demo account:")
        print(f"\n    {password}\n")
        print("Store it now - it is not written anywhere and will not be shown again.")
    else:
        print("\nUsing the password from SEED_PASSWORD.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
