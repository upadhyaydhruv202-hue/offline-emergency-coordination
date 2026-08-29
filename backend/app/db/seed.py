"""Create the demo responder accounts.

Run with::

    python -m app.db.seed
    python -m app.db.seed --victims    # also insert demo casualties

Credentials are never stored in source. The password comes from ``SEED_PASSWORD``;
if it is absent, a strong one is generated and printed once so the operator can
record it.
"""

from __future__ import annotations

import secrets
import sys
import uuid
from dataclasses import dataclass

from sqlalchemy.orm import Session

from app.core.config import settings
from app.db.session import SessionFactory
from app.models.enums import AgeGroup, Gender, TriageCategory, UserRole, VictimStatus
from app.repositories.user_repository import UserRepository
from app.repositories.victim_repository import VictimRepository
from app.schemas.user import UserCreate
from app.schemas.victim import VictimCreate
from app.services.auth_service import AuthService
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
    ),
    SeedCasualty(
        "V-SEED-002",
        None,
        None,
        TriageCategory.CRITICAL,
        VictimStatus.UNDER_TREATMENT,
        "Head trauma, unresponsive",
    ),
    SeedCasualty(
        "V-SEED-003",
        "R. Verma",
        58,
        TriageCategory.URGENT,
        VictimStatus.REGISTERED,
        "Open fracture, right forearm",
    ),
    SeedCasualty(
        "V-SEED-004",
        "M. Iyer",
        9,
        TriageCategory.MODERATE,
        VictimStatus.REGISTERED,
        "Lacerations, smoke inhalation",
    ),
    SeedCasualty(
        "V-SEED-005",
        "K. Nair",
        33,
        TriageCategory.STABLE,
        VictimStatus.EVACUATED,
        "Minor abrasions",
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
            )
        )
        created += 1

    return created, skipped


def main() -> int:
    password, generated = resolve_seed_password()
    with_victims = "--victims" in sys.argv[1:]

    with SessionFactory() as session:
        created, skipped = seed_users(session, password)
        session.commit()

        if with_victims:
            victims_created, victims_skipped = seed_victims(session)
            session.commit()

    print(f"Seed complete: {created} created, {skipped} already present.")
    for persona in PERSONAS:
        print(f"  {persona.role.value:<20} {persona.email}")

    if with_victims:
        print(
            f"\nDemo casualties: {victims_created} created, "
            f"{victims_skipped} already present. Tagged V-SEED-*."
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
