"""The responder roster.

Deliberately thin: a responder *is* a :class:`~app.models.user.User`, so this
reuses :class:`~app.schemas.user.UserRead` rather than introducing a second,
divergent representation of the same row. Availability
(:class:`~app.models.enums.ResponderStatus`) is not here because no column
stores it yet - devices do not report their own state until a later slice.
"""

from __future__ import annotations

from pydantic import BaseModel

from app.schemas.user import UserRead


class ResponderPage(BaseModel):
    items: list[UserRead]
    total: int
