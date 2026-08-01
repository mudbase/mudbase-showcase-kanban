"""activity collection: board-wide read granted to all three roles;
creation happens implicitly as a side effect of every list/card write made
by owner/member (there is no direct end-user-facing "post an activity row"
action) — enforced server-side by Mudbase collection permissions.

`action` values written by this app: `created_card`, `moved` (covers both
cross-list moves and same-list reorders — a same-list reorder logs `moved`
with `from_list == to_list`), `deleted_card`, `created_list`, `renamed_list`,
`deleted_list`. See plan/build-plan.md for the full rationale.
"""

import asyncio

from app.config import get_settings
from app.mudbase_client import create_data_sync, list_data_sync
from app.schemas.activity import ActivityEntry

_FEED_LIMIT = 100  # Mudbase's DataApi.list_data caps `limit` at 100 server-side (an SDK-level
# Pydantic constraint) — confirmed live during this build. The reference ../web app's
# ACTIVITY_LIMIT=200 constant is a browser-side fetch against the raw REST API, which does not
# go through this Python SDK's stricter client-side validation, so that higher value doesn't
# carry over here.


async def list_activity(*, access_token: str) -> list[ActivityEntry]:
    settings = get_settings()
    result = await asyncio.to_thread(
        list_data_sync,
        settings.activity_collection_id,
        filter_dict={"boardId": settings.board_id},
        sort="-createdAt",
        limit=_FEED_LIMIT,
        access_token=access_token,
    )
    return [ActivityEntry.model_validate(doc) for doc in result["data"]]


async def log_activity(
    *,
    actor_id: str,
    actor_name: str,
    action: str,
    card_title: str | None = None,
    from_list: str | None = None,
    to_list: str | None = None,
    access_token: str,
) -> ActivityEntry:
    settings = get_settings()
    body: dict[str, object] = {
        "boardId": settings.board_id,
        "actorId": actor_id,
        "actorName": actor_name,
        "action": action,
    }
    if card_title is not None:
        body["cardTitle"] = card_title
    if from_list is not None:
        body["fromList"] = from_list
    if to_list is not None:
        body["toList"] = to_list
    doc = await asyncio.to_thread(create_data_sync, settings.activity_collection_id, body, access_token=access_token)
    return ActivityEntry.model_validate(doc)
