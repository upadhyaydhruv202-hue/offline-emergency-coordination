"""Create the demo responder accounts.

Run with::

    python -m app.db.seed

Credentials are never stored in source. The password comes from ``SEED_PASSWORD``;
if it is absent, a strong one is generated and printed once so the operator can
record it.
"""

from __future__ import annotations

import secrets
import sys
from dataclasses import dataclass

from sqlalchemy.orm import Session

from app.core.config import settings
from app.db.session import SessionFactory
from app.models.enums import UserRole
from app.repositories.user_repository import UserRepository
from app.schemas.user import UserCreate
from app.services.auth_service import AuthService


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


def main() -> int:
    password, generated = resolve_seed_password()

    with SessionFactory() as session:
        created, skipped = seed_users(session, password)
        session.commit()

    print(f"Seed complete: {created} created, {skipped} already present.")
    for persona in PERSONAS:
        print(f"  {persona.role.value:<20} {persona.email}")

    if generated:
        print("\nSEED_PASSWORD was not set. Generated password for every demo account:")
        print(f"\n    {password}\n")
        print("Store it now - it is not written anywhere and will not be shown again.")
    else:
        print("\nUsing the password from SEED_PASSWORD.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
