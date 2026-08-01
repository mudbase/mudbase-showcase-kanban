"""Mirrors ../web/src/types/activity.ts. `action` is a free string rather
than a Python enum on purpose — see plan/build-plan.md for the exact set of
values this app writes (created_card, moved, deleted_card, created_list,
renamed_list, deleted_list); rendering just falls back to the raw string for
anything unrecognized, so a future extra action type never breaks the feed.
"""

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class ActivityEntry(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: str = Field(alias="_id")
    board_id: str = Field(alias="boardId")
    actor_id: str = Field(alias="actorId")
    actor_name: str = Field(alias="actorName")
    action: str
    card_title: str | None = Field(default=None, alias="cardTitle")
    from_list: str | None = Field(default=None, alias="fromList")
    to_list: str | None = Field(default=None, alias="toList")
    created_at: datetime | None = Field(default=None, alias="createdAt")
