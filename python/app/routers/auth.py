"""Login / logout. Mirrors ../web/src/app/login and
../web/src/components/auth/LoginForm.tsx. There is no register/verify-email
flow — this app has no self-registration UI (see plan/build-plan.md "Auth
Model"); every role signs in with one of the three already-provisioned
demo accounts (quick sign-in buttons) or a manually typed email/password.
"""

import logging
from typing import Annotated, Any

from fastapi import APIRouter, Form, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from pydantic import ValidationError

from app.config import get_settings
from app.context import build_base_context
from app.mudbase_client import MudbaseApiError
from app.schemas.auth import LoginFormValues
from app.services import auth_service
from app.session import clear_session, get_session_user, get_valid_access_token, set_flash, store_session
from app.templates_env import templates

router = APIRouter()
logger = logging.getLogger(__name__)


def _safe_next(next_url: str | None) -> str:
    """Guards against an open redirect via the `next` param: only a
    same-origin, path-absolute value is honored. `next_url.startswith("//")`
    is rejected too — a browser treats `//evil.example` as a protocol-relative
    URL to a different host, not a path on this one."""
    if next_url and next_url.startswith("/") and not next_url.startswith("//"):
        return next_url
    return "/"


def _demo_accounts_context(next_url: str | None) -> dict[str, Any]:
    settings = get_settings()
    return {
        "next": _safe_next(next_url) if next_url else None,
        "demo_password": settings.demo_password,
        "demo_accounts": [
            {"role": "Owner", "email": settings.demo_owner_email},
            {"role": "Member", "email": settings.demo_member_email},
            {"role": "Viewer", "email": settings.demo_viewer_email},
        ],
    }


@router.get("/login", response_class=HTMLResponse, response_model=None)
async def login_page(request: Request, next: str | None = None) -> HTMLResponse | RedirectResponse:
    if get_session_user(request) is not None:
        return RedirectResponse(_safe_next(next), status_code=303)
    context = await build_base_context(request)
    context.update({"errors": {}, "form_error": None})
    context.update(_demo_accounts_context(next))
    return templates.TemplateResponse(request=request, name="login.html", context=context)


@router.post("/login", response_class=HTMLResponse, response_model=None)
async def login_submit(
    request: Request,
    email: Annotated[str, Form()],
    password: Annotated[str, Form()],
    next: Annotated[str | None, Form()] = None,
) -> HTMLResponse | RedirectResponse:
    try:
        values = LoginFormValues(email=email, password=password)
    except ValidationError as exc:
        context = await build_base_context(request)
        context.update({"errors": _field_errors(exc), "form_error": None})
        context.update(_demo_accounts_context(next))
        return templates.TemplateResponse(request=request, name="login.html", context=context, status_code=422)

    try:
        result = await auth_service.login(values.email, values.password)
    except MudbaseApiError as exc:
        context = await build_base_context(request)
        context.update({"errors": {}, "form_error": exc.message})
        context.update(_demo_accounts_context(next))
        return templates.TemplateResponse(request=request, name="login.html", context=context, status_code=401)

    user = result.get("user") or {}
    store_session(
        request,
        user=user,
        token=result["token"],
        refresh_token=result["refreshToken"],
        expires_in=result.get("expiresIn"),
    )
    set_flash(request, "Welcome back!", "success")
    return RedirectResponse(_safe_next(next), status_code=303)


@router.post("/logout", response_model=None)
async def logout_submit(request: Request) -> RedirectResponse:
    token = await get_valid_access_token(request)
    if token:
        try:
            await auth_service.logout(token)
        except MudbaseApiError as exc:
            # Session is cleared locally regardless of the remote logout outcome (an
            # already-expired token, for instance, shouldn't strand the user signed in).
            logger.warning("Remote logout failed for a local session teardown: %s", exc.message)
    clear_session(request)
    return RedirectResponse("/login", status_code=303)


def _field_errors(exc: ValidationError) -> dict[str, str]:
    errors: dict[str, str] = {}
    for error in exc.errors():
        field = str(error["loc"][0]) if error["loc"] else "form"
        errors[field] = error["msg"]
    return errors
