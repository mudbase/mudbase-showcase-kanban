"""The board page plus every list/card write. Mirrors ../web/src/app/page.tsx
and ../web/src/hooks/useLists.ts / useCards.ts.

Every mutating handler re-checks `app.rbac` before calling a service — this
app's own defense-in-depth gate — but the real enforcement boundary is
Mudbase's own collection permissions (see plan/build-plan.md "Live smoke
test results" for a raw write attempt as `viewer` that bypasses this app's
routers entirely and still gets a 403 from the platform).

No realtime subscription here (unlike the reference SPA's Socket.IO rooms)
— matching the sibling `mudbase-showcase-social`/`mudbase-showcase-ecommerce`
Python ports' own precedent: this is plain request/response HTML, a page
reload is how a visitor sees another user's change.
"""

import logging
from collections import defaultdict
from typing import Annotated

from fastapi import APIRouter, Form, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from pydantic import ValidationError

from app import rbac
from app.context import build_base_context
from app.mudbase_client import MudbaseApiError
from app.schemas.card import BoardCard, CardFormValues
from app.schemas.list_ import BoardList, ListFormValues
from app.services import activity as activity_service
from app.services import cards as cards_service
from app.services import lists as lists_service
from app.session import SessionUser, call_with_reauth, require_session, set_flash
from app.templates_env import templates

router = APIRouter()
logger = logging.getLogger(__name__)


def _actor_fields(user: SessionUser) -> tuple[str, str]:
    return user.id, user.display_name


@router.get("/", response_class=HTMLResponse, response_model=None)
async def board_index(request: Request) -> HTMLResponse | RedirectResponse:
    gate = await require_session(request)
    if gate is None:
        return RedirectResponse("/login?next=/", status_code=303)
    _user, token = gate

    lists: list[BoardList]
    cards: list[BoardCard]
    load_error: str | None
    try:
        lists, token = await call_with_reauth(request, token, lambda t: lists_service.list_board_lists(access_token=t))
        cards, token = await call_with_reauth(request, token, lambda t: cards_service.list_board_cards(access_token=t))
        load_error = None
    except MudbaseApiError as exc:
        lists, cards, load_error = [], [], f"Couldn't load the board right now: {exc.message}"

    cards_by_list: dict[str, list[BoardCard]] = defaultdict(list)
    for card in cards:
        cards_by_list[card.list_id].append(card)

    context = await build_base_context(request)
    context.update(
        {
            "lists": lists,
            "cards_by_list": cards_by_list,
            "load_error": load_error,
        }
    )
    return templates.TemplateResponse(request=request, name="board.html", context=context)


# ─── Lists (owner-only) ──────────────────────────────────────────────────────


@router.post("/lists", response_model=None)
async def create_list_submit(request: Request, name: Annotated[str, Form()]) -> RedirectResponse:
    gate = await require_session(request)
    if gate is None:
        return RedirectResponse("/login?next=/", status_code=303)
    user, token = gate
    if not rbac.can_manage_lists(user.custom_role):
        set_flash(request, "Only the board owner can manage lists.", "error")
        return RedirectResponse("/", status_code=303)

    try:
        values = ListFormValues(name=name)
    except ValidationError:
        set_flash(request, "Give the list a name.", "error")
        return RedirectResponse("/", status_code=303)

    actor_id, actor_name = _actor_fields(user)
    try:
        position, token = await call_with_reauth(request, token, lambda t: lists_service.next_list_position(access_token=t))
        created, token = await call_with_reauth(
            request, token, lambda t: lists_service.create_list(values.name, position=position, access_token=t)
        )
        await call_with_reauth(
            request,
            token,
            lambda t: activity_service.log_activity(
                actor_id=actor_id, actor_name=actor_name, action="created_list", to_list=created.name, access_token=t
            ),
        )
    except MudbaseApiError as exc:
        set_flash(request, f"Couldn't create that list: {exc.message}", "error")
        return RedirectResponse("/", status_code=303)

    set_flash(request, "List created.", "success")
    return RedirectResponse("/", status_code=303)


@router.post("/lists/{list_id}/rename", response_model=None)
async def rename_list_submit(request: Request, list_id: str, name: Annotated[str, Form()]) -> RedirectResponse:
    gate = await require_session(request)
    if gate is None:
        return RedirectResponse("/login?next=/", status_code=303)
    user, token = gate
    if not rbac.can_manage_lists(user.custom_role):
        set_flash(request, "Only the board owner can manage lists.", "error")
        return RedirectResponse("/", status_code=303)

    try:
        values = ListFormValues(name=name)
    except ValidationError:
        set_flash(request, "Give the list a name.", "error")
        return RedirectResponse("/", status_code=303)

    actor_id, actor_name = _actor_fields(user)
    try:
        board_list, token = await call_with_reauth(request, token, lambda t: lists_service.get_list(list_id, access_token=t))
        if board_list is None:
            set_flash(request, "That list no longer exists.", "error")
            return RedirectResponse("/", status_code=303)
        old_name = board_list.name
        await call_with_reauth(
            request, token, lambda t: lists_service.rename_list(board_list, values.name, access_token=t)
        )
        await call_with_reauth(
            request,
            token,
            lambda t: activity_service.log_activity(
                actor_id=actor_id,
                actor_name=actor_name,
                action="renamed_list",
                from_list=old_name,
                to_list=values.name,
                access_token=t,
            ),
        )
    except MudbaseApiError as exc:
        set_flash(request, f"Couldn't rename that list: {exc.message}", "error")
        return RedirectResponse("/", status_code=303)

    set_flash(request, "List renamed.", "success")
    return RedirectResponse("/", status_code=303)


@router.post("/lists/{list_id}/reorder", response_model=None)
async def reorder_list_submit(request: Request, list_id: str, direction: Annotated[str, Form()]) -> RedirectResponse:
    gate = await require_session(request)
    if gate is None:
        return RedirectResponse("/login?next=/", status_code=303)
    user, token = gate
    if not rbac.can_manage_lists(user.custom_role):
        set_flash(request, "Only the board owner can manage lists.", "error")
        return RedirectResponse("/", status_code=303)

    try:
        all_lists, token = await call_with_reauth(request, token, lambda t: lists_service.list_board_lists(access_token=t))
        index = next((i for i, board_list in enumerate(all_lists) if board_list.id == list_id), None)
        if index is None:
            set_flash(request, "That list no longer exists.", "error")
            return RedirectResponse("/", status_code=303)
        neighbor_index = index - 1 if direction == "left" else index + 1
        if neighbor_index < 0 or neighbor_index >= len(all_lists):
            return RedirectResponse("/", status_code=303)
        current_list = all_lists[index]
        neighbor = all_lists[neighbor_index]
        await call_with_reauth(
            request, token, lambda t: lists_service.reorder_list(current_list, neighbor, access_token=t)
        )
    except MudbaseApiError as exc:
        set_flash(request, f"Couldn't reorder that list: {exc.message}", "error")
        return RedirectResponse("/", status_code=303)

    return RedirectResponse("/", status_code=303)


@router.post("/lists/{list_id}/delete", response_model=None)
async def delete_list_submit(request: Request, list_id: str) -> RedirectResponse:
    gate = await require_session(request)
    if gate is None:
        return RedirectResponse("/login?next=/", status_code=303)
    user, token = gate
    if not rbac.can_manage_lists(user.custom_role):
        set_flash(request, "Only the board owner can manage lists.", "error")
        return RedirectResponse("/", status_code=303)

    actor_id, actor_name = _actor_fields(user)
    try:
        board_list, token = await call_with_reauth(request, token, lambda t: lists_service.get_list(list_id, access_token=t))
        if board_list is None:
            set_flash(request, "That list no longer exists.", "error")
            return RedirectResponse("/", status_code=303)
        await call_with_reauth(request, token, lambda t: lists_service.delete_list(board_list, access_token=t))
        await call_with_reauth(
            request,
            token,
            lambda t: activity_service.log_activity(
                actor_id=actor_id, actor_name=actor_name, action="deleted_list", from_list=board_list.name, access_token=t
            ),
        )
    except MudbaseApiError as exc:
        set_flash(request, f"Couldn't delete that list: {exc.message}", "error")
        return RedirectResponse("/", status_code=303)

    set_flash(request, "List deleted.", "success")
    return RedirectResponse("/", status_code=303)


# ─── Cards (owner + member) ──────────────────────────────────────────────────


@router.post("/cards", response_model=None)
async def create_card_submit(
    request: Request,
    list_id: Annotated[str, Form()],
    title: Annotated[str, Form()],
    description: Annotated[str, Form()] = "",
    assignee_name: Annotated[str, Form()] = "",
) -> RedirectResponse:
    gate = await require_session(request)
    if gate is None:
        return RedirectResponse("/login?next=/", status_code=303)
    user, token = gate
    if not rbac.can_manage_cards(user.custom_role):
        set_flash(request, "You don't have permission to add cards.", "error")
        return RedirectResponse("/", status_code=303)

    try:
        values = CardFormValues(title=title, description=description, assignee_name=assignee_name)
    except ValidationError:
        set_flash(request, "Give the card a title.", "error")
        return RedirectResponse("/", status_code=303)

    actor_id, actor_name = _actor_fields(user)
    try:
        board_list, token = await call_with_reauth(request, token, lambda t: lists_service.get_list(list_id, access_token=t))
        if board_list is None:
            set_flash(request, "That list no longer exists.", "error")
            return RedirectResponse("/", status_code=303)
        position, token = await call_with_reauth(
            request, token, lambda t: cards_service.next_position_in_list(list_id, access_token=t)
        )
        await call_with_reauth(
            request,
            token,
            lambda t: cards_service.create_card(
                values,
                list_id=list_id,
                position=position,
                created_by_id=actor_id,
                created_by_name=actor_name,
                access_token=t,
            ),
        )
        await call_with_reauth(
            request,
            token,
            lambda t: activity_service.log_activity(
                actor_id=actor_id,
                actor_name=actor_name,
                action="created_card",
                card_title=values.title,
                to_list=board_list.name,
                access_token=t,
            ),
        )
    except MudbaseApiError as exc:
        set_flash(request, f"Couldn't create that card: {exc.message}", "error")
        return RedirectResponse("/", status_code=303)

    set_flash(request, "Card created.", "success")
    return RedirectResponse("/", status_code=303)


@router.post("/cards/{card_id}/edit", response_model=None)
async def edit_card_submit(
    request: Request,
    card_id: str,
    title: Annotated[str, Form()],
    description: Annotated[str, Form()] = "",
    assignee_name: Annotated[str, Form()] = "",
) -> RedirectResponse:
    gate = await require_session(request)
    if gate is None:
        return RedirectResponse("/login?next=/", status_code=303)
    user, token = gate
    if not rbac.can_manage_cards(user.custom_role):
        set_flash(request, "You don't have permission to edit cards.", "error")
        return RedirectResponse("/", status_code=303)

    try:
        values = CardFormValues(title=title, description=description, assignee_name=assignee_name)
    except ValidationError:
        set_flash(request, "Give the card a title.", "error")
        return RedirectResponse("/", status_code=303)

    try:
        card, token = await call_with_reauth(request, token, lambda t: cards_service.get_card(card_id, access_token=t))
        if card is None:
            set_flash(request, "That card no longer exists.", "error")
            return RedirectResponse("/", status_code=303)
        await call_with_reauth(request, token, lambda t: cards_service.update_card(card, values, access_token=t))
    except MudbaseApiError as exc:
        set_flash(request, f"Couldn't update that card: {exc.message}", "error")
        return RedirectResponse("/", status_code=303)

    set_flash(request, "Card updated.", "success")
    return RedirectResponse("/", status_code=303)


@router.post("/cards/{card_id}/delete", response_model=None)
async def delete_card_submit(request: Request, card_id: str) -> RedirectResponse:
    gate = await require_session(request)
    if gate is None:
        return RedirectResponse("/login?next=/", status_code=303)
    user, token = gate
    if not rbac.can_manage_cards(user.custom_role):
        set_flash(request, "You don't have permission to delete cards.", "error")
        return RedirectResponse("/", status_code=303)

    actor_id, actor_name = _actor_fields(user)
    try:
        card, token = await call_with_reauth(request, token, lambda t: cards_service.get_card(card_id, access_token=t))
        if card is None:
            set_flash(request, "That card no longer exists.", "error")
            return RedirectResponse("/", status_code=303)
        board_list, token = await call_with_reauth(
            request, token, lambda t: lists_service.get_list(card.list_id, access_token=t)
        )
        list_name = board_list.name if board_list else "Unknown list"
        await call_with_reauth(request, token, lambda t: cards_service.delete_card(card, access_token=t))
        await call_with_reauth(
            request,
            token,
            lambda t: activity_service.log_activity(
                actor_id=actor_id,
                actor_name=actor_name,
                action="deleted_card",
                card_title=card.title,
                from_list=list_name,
                access_token=t,
            ),
        )
    except MudbaseApiError as exc:
        set_flash(request, f"Couldn't delete that card: {exc.message}", "error")
        return RedirectResponse("/", status_code=303)

    set_flash(request, "Card deleted.", "success")
    return RedirectResponse("/", status_code=303)


@router.post("/cards/{card_id}/move-to", response_model=None)
async def move_card_submit(request: Request, card_id: str, to_list_id: Annotated[str, Form()]) -> RedirectResponse:
    gate = await require_session(request)
    if gate is None:
        return RedirectResponse("/login?next=/", status_code=303)
    user, token = gate
    if not rbac.can_manage_cards(user.custom_role):
        set_flash(request, "You don't have permission to move cards.", "error")
        return RedirectResponse("/", status_code=303)

    actor_id, actor_name = _actor_fields(user)
    try:
        card, token = await call_with_reauth(request, token, lambda t: cards_service.get_card(card_id, access_token=t))
        if card is None:
            set_flash(request, "That card no longer exists.", "error")
            return RedirectResponse("/", status_code=303)
        if card.list_id == to_list_id:
            return RedirectResponse("/", status_code=303)
        from_list, token = await call_with_reauth(
            request, token, lambda t: lists_service.get_list(card.list_id, access_token=t)
        )
        to_list, token = await call_with_reauth(request, token, lambda t: lists_service.get_list(to_list_id, access_token=t))
        if to_list is None:
            set_flash(request, "That list no longer exists.", "error")
            return RedirectResponse("/", status_code=303)
        new_position, token = await call_with_reauth(
            request, token, lambda t: cards_service.next_position_in_list(to_list_id, access_token=t)
        )
        await call_with_reauth(
            request,
            token,
            lambda t: cards_service.move_card_to_list(card, to_list_id=to_list_id, new_position=new_position, access_token=t),
        )
        await call_with_reauth(
            request,
            token,
            lambda t: activity_service.log_activity(
                actor_id=actor_id,
                actor_name=actor_name,
                action="moved",
                card_title=card.title,
                from_list=from_list.name if from_list else "Unknown list",
                to_list=to_list.name,
                access_token=t,
            ),
        )
    except MudbaseApiError as exc:
        set_flash(request, f"Couldn't move that card: {exc.message}", "error")
        return RedirectResponse("/", status_code=303)

    set_flash(request, "Card moved.", "success")
    return RedirectResponse("/", status_code=303)


@router.post("/cards/{card_id}/reorder", response_model=None)
async def reorder_card_submit(request: Request, card_id: str, direction: Annotated[str, Form()]) -> RedirectResponse:
    gate = await require_session(request)
    if gate is None:
        return RedirectResponse("/login?next=/", status_code=303)
    user, token = gate
    if not rbac.can_manage_cards(user.custom_role):
        set_flash(request, "You don't have permission to move cards.", "error")
        return RedirectResponse("/", status_code=303)

    actor_id, actor_name = _actor_fields(user)
    try:
        card, token = await call_with_reauth(request, token, lambda t: cards_service.get_card(card_id, access_token=t))
        if card is None:
            set_flash(request, "That card no longer exists.", "error")
            return RedirectResponse("/", status_code=303)
        siblings, token = await call_with_reauth(
            request, token, lambda t: cards_service.list_cards_in_list(card.list_id, access_token=t)
        )
        index = next((i for i, sibling in enumerate(siblings) if sibling.id == card.id), None)
        if index is None:
            return RedirectResponse("/", status_code=303)
        neighbor_index = index - 1 if direction == "up" else index + 1
        if neighbor_index < 0 or neighbor_index >= len(siblings):
            return RedirectResponse("/", status_code=303)
        neighbor = siblings[neighbor_index]
        board_list, token = await call_with_reauth(
            request, token, lambda t: lists_service.get_list(card.list_id, access_token=t)
        )
        list_name = board_list.name if board_list else "Unknown list"
        await call_with_reauth(request, token, lambda t: cards_service.reorder_card_in_list(card, neighbor, access_token=t))
        await call_with_reauth(
            request,
            token,
            lambda t: activity_service.log_activity(
                actor_id=actor_id,
                actor_name=actor_name,
                action="moved",
                card_title=card.title,
                from_list=list_name,
                to_list=list_name,
                access_token=t,
            ),
        )
    except MudbaseApiError as exc:
        set_flash(request, f"Couldn't reorder that card: {exc.message}", "error")
        return RedirectResponse("/", status_code=303)

    return RedirectResponse("/", status_code=303)
