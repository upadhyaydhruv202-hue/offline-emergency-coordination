"""Single import surface for Alembic autogenerate.

Importing every model here guarantees ``Base.metadata`` is fully populated
before migrations are generated.
"""

from app.models.audit_event import AuditEvent  # noqa: F401
from app.models.base import Base
from app.models.facility import Facility  # noqa: F401
from app.models.hazard import Hazard  # noqa: F401
from app.models.incident import Incident  # noqa: F401
from app.models.responder_presence import ResponderPresence  # noqa: F401
from app.models.sos_event import SosEvent  # noqa: F401
from app.models.sync_conflict import SyncConflict  # noqa: F401
from app.models.sync_operation import SyncOperation  # noqa: F401
from app.models.task import Task  # noqa: F401
from app.models.user import User  # noqa: F401
from app.models.victim import Victim  # noqa: F401

__all__ = ["Base"]
