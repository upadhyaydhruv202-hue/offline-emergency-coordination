"""Single import surface for Alembic autogenerate.

Importing every model here guarantees ``Base.metadata`` is fully populated
before migrations are generated.
"""

from app.models.base import Base
from app.models.user import User  # noqa: F401  (registers the table)

__all__ = ["Base"]
