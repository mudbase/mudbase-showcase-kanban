"""Full reverse-chronological activity feed. Mirrors
../web/src/app/activity/page.tsx."""

from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse, RedirectResponse

from app.context import build_base_context
from app.mudbase_client import MudbaseApiError
from app.schemas.activity import ActivityEntry
from app.services import activity as activity_service
from app.session import call_with_reauth, require_session
from app.templates_env import templates

router = APIRouter()


@router.get("/activity", response_class=HTMLResponse, response_model=None)
async def activity_index(request: Request) -> HTMLResponse | RedirectResponse:
    gate = await require_session(request)
    if gate is None:
        return RedirectResponse("/login?next=/activity", status_code=303)
    user, token = gate

    entries: list[ActivityEntry]
    load_error: str | None
    try:
        entries, _token = await call_with_reauth(request, token, lambda t: activity_service.list_activity(access_token=t))
        load_error = None
    except MudbaseApiError as exc:
        entries, load_error = [], f"Couldn't load the activity feed right now: {exc.message}"

    context = await build_base_context(request)
    context.update({"entries": entries, "load_error": load_error})
    return templates.TemplateResponse(request=request, name="activity.html", context=context)
