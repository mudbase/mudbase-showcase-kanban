"""cards collection: board-wide read granted to all three roles,
create/update/delete restricted to owner/member — enforced server-side by
Mudbase collection permissions (see plan/build-plan.md), not re-checked
here (routers re-check via app.rbac before ever calling this module, but
the real boundary is Mudbase's own permissions).

`assignee_id` is derived from the free-typed `assignee_name` via
`pseudo_object_id` (see app/utils.py) since `cards.assigneeId` is
schema-typed as an ObjectId reference and there is no `users` collection to
resolve a real one from. Clearing an assignee sends `None` for both fields —
`""` is rejected by the platform the same way an invalid slug would be
(confirmed live, see plan/build-plan.md).
"""

import asyncio
from typing import Any

from app.config import get_settings
from app.mudbase_client import create_data_sync, delete_data_sync, get_data_sync, list_data_sync, update_data_sync
from app.schemas.card import BoardCard, CardFormValues
from app.utils import pseudo_object_id

_LIST_CARDS_LIMIT = 100  # Mudbase's DataApi.list_data caps `limit` at 100 server-side.


async def list_board_cards(*, access_token: str) -> list[BoardCard]:
    """All cards for the single shared board, ascending by in-column order —
    fetched once and grouped by list_id by the caller, rather than one query
    per column (mirrors ../web/src/hooks/useCards.ts::useBoardCards)."""
    settings = get_settings()
    result = await asyncio.to_thread(
        list_data_sync,
        settings.cards_collection_id,
        filter_dict={"boardId": settings.board_id},
        sort="position",
        limit=_LIST_CARDS_LIMIT,
        access_token=access_token,
    )
    return [BoardCard.model_validate(doc) for doc in result["data"]]


async def list_cards_in_list(list_id: str, *, access_token: str) -> list[BoardCard]:
    """Cards belonging to one column, ascending by position. `list_id` is a
    real ObjectId (a `lists` document's own `_id`), so filtering on it is
    safe under Mudbase's ObjectId-suffix query sanitizer."""
    settings = get_settings()
    result = await asyncio.to_thread(
        list_data_sync,
        settings.cards_collection_id,
        filter_dict={"listId": list_id},
        sort="position",
        limit=_LIST_CARDS_LIMIT,
        access_token=access_token,
    )
    return [BoardCard.model_validate(doc) for doc in result["data"]]


async def get_card(card_id: str, *, access_token: str) -> BoardCard | None:
    settings = get_settings()
    doc = await asyncio.to_thread(get_data_sync, settings.cards_collection_id, card_id, access_token=access_token)
    return BoardCard.model_validate(doc) if doc else None


async def next_position_in_list(list_id: str, *, access_token: str) -> float:
    """One past the highest existing position in this column, or 0 if the
    column is empty — new cards/lists always append to the end."""
    cards = await list_cards_in_list(list_id, access_token=access_token)
    if not cards:
        return 0.0
    return max(card.position for card in cards) + 1.0


async def create_card(
    values: CardFormValues,
    *,
    list_id: str,
    position: float,
    created_by_id: str,
    created_by_name: str,
    access_token: str,
) -> BoardCard:
    settings = get_settings()
    body: dict[str, Any] = {
        "boardId": settings.board_id,
        "listId": list_id,
        "title": values.title,
        "position": position,
        "createdById": created_by_id,
        "createdByName": created_by_name,
    }
    if values.description:
        body["description"] = values.description
    if values.assignee_name:
        body["assigneeId"] = pseudo_object_id(values.assignee_name)
        body["assigneeName"] = values.assignee_name
    doc = await asyncio.to_thread(create_data_sync, settings.cards_collection_id, body, access_token=access_token)
    return BoardCard.model_validate(doc)


async def update_card(card: BoardCard, values: CardFormValues, *, access_token: str) -> BoardCard:
    settings = get_settings()
    # `assigneeId: ""` is rejected server-side ("Invalid ObjectId format for assigneeId") —
    # `None` is what actually clears it. Never send "" here (see module docstring).
    body: dict[str, Any] = {
        "title": values.title,
        "description": values.description or "",
        "assigneeId": pseudo_object_id(values.assignee_name) if values.assignee_name else None,
        "assigneeName": values.assignee_name or None,
    }
    doc = await asyncio.to_thread(
        update_data_sync, settings.cards_collection_id, card.id, body, access_token=access_token
    )
    return BoardCard.model_validate(doc)


async def delete_card(card: BoardCard, *, access_token: str) -> None:
    settings = get_settings()
    await asyncio.to_thread(delete_data_sync, settings.cards_collection_id, card.id, access_token=access_token)


async def move_card_to_list(card: BoardCard, *, to_list_id: str, new_position: float, access_token: str) -> BoardCard:
    """Cross-list move: card is appended to the end of the target column."""
    settings = get_settings()
    doc = await asyncio.to_thread(
        update_data_sync,
        settings.cards_collection_id,
        card.id,
        {"listId": to_list_id, "position": new_position},
        access_token=access_token,
    )
    return BoardCard.model_validate(doc)


async def reorder_card_in_list(card: BoardCard, neighbor: BoardCard, *, access_token: str) -> None:
    """Same-list reorder via a two-write position swap with the adjacent
    card — correct and simple at demo scale (see plan/build-plan.md "Known
    Limitations" for why this wouldn't scale to very large lists)."""
    settings = get_settings()
    await asyncio.to_thread(
        update_data_sync,
        settings.cards_collection_id,
        card.id,
        {"position": neighbor.position},
        access_token=access_token,
    )
    await asyncio.to_thread(
        update_data_sync,
        settings.cards_collection_id,
        neighbor.id,
        {"position": card.position},
        access_token=access_token,
    )
