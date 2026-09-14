"""Single import surface for Alembic autogenerate.

Importing every model here guarantees ``Base.metadata`` is fully populated
before migrations are generated.
"""

from app.models.base import Base
from app.models.hazard import Hazard  # noqa: F401  (registers the table)
from app.models.incident import Incident  # noqa: F401  (registers the table)
from app.models.sos_event import SosEvent  # noqa: F401  (registers the table)
from app.models.task import Task  # noqa: F401  (registers the table)
from app.models.user import User  # noqa: F401  (registers the table)
from app.models.victim import Victim  # noqa: F401  (registers the table)

__all__ = ["Base"]
