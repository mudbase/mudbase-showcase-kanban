"""lists collection: board-wide read granted to all three roles,
create/rename/delete/reorder restricted to owner only — enforced
server-side by Mudbase collection permissions (see plan/build-plan.md).
"""

import asyncio

from app.config import get_settings
from app.mudbase_client import create_data_sync, delete_data_sync, get_data_sync, list_data_sync, update_data_sync
from app.schemas.list_ import BoardList
from app.services.cards import list_cards_in_list
from app.services.cards import delete_card as delete_card_row

_LISTS_LIMIT = 100  # Mudbase's DataApi.list_data caps `limit` at 100 server-side.


async def list_board_lists(*, access_token: str) -> list[BoardList]:
    settings = get_settings()
    result = await asyncio.to_thread(
        list_data_sync,
        settings.lists_collection_id,
        filter_dict={"boardId": settings.board_id},
        sort="position",
        limit=_LISTS_LIMIT,
        access_token=access_token,
    )
    return [BoardList.model_validate(doc) for doc in result["data"]]


async def get_list(list_id: str, *, access_token: str) -> BoardList | None:
    settings = get_settings()
    doc = await asyncio.to_thread(get_data_sync, settings.lists_collection_id, list_id, access_token=access_token)
    return BoardList.model_validate(doc) if doc else None


async def next_list_position(*, access_token: str) -> float:
    lists = await list_board_lists(access_token=access_token)
    if not lists:
        return 0.0
    return max(board_list.position for board_list in lists) + 1.0


async def create_list(name: str, *, position: float, access_token: str) -> BoardList:
    settings = get_settings()
    doc = await asyncio.to_thread(
        create_data_sync,
        settings.lists_collection_id,
        {"boardId": settings.board_id, "name": name, "position": position},
        access_token=access_token,
    )
    return BoardList.model_validate(doc)


async def rename_list(board_list: BoardList, new_name: str, *, access_token: str) -> BoardList:
    settings = get_settings()
    doc = await asyncio.to_thread(
        update_data_sync,
        settings.lists_collection_id,
        board_list.id,
        {"name": new_name},
        access_token=access_token,
    )
    return BoardList.model_validate(doc)


async def reorder_list(board_list: BoardList, neighbor: BoardList, *, access_token: str) -> None:
    """Swaps this list's position with an adjacent one (left/right column
    reorder), mirroring ../web/src/hooks/useLists.ts::useReorderList."""
    settings = get_settings()
    await asyncio.to_thread(
        update_data_sync,
        settings.lists_collection_id,
        board_list.id,
        {"position": neighbor.position},
        access_token=access_token,
    )
    await asyncio.to_thread(
        update_data_sync,
        settings.lists_collection_id,
        neighbor.id,
        {"position": board_list.position},
        access_token=access_token,
    )


async def delete_list(board_list: BoardList, *, access_token: str) -> None:
    """Deletes a column and cascades to every card inside it — a list's
    cards have nowhere else to live once the column is gone, there's no
    "uncategorized" list to fall back to (mirrors
    ../web/src/hooks/useLists.ts::useDeleteList)."""
    settings = get_settings()
    cards_in_list = await list_cards_in_list(board_list.id, access_token=access_token)
    for card in cards_in_list:
        await delete_card_row(card, access_token=access_token)
    await asyncio.to_thread(delete_data_sync, settings.lists_collection_id, board_list.id, access_token=access_token)
