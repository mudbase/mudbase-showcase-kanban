"""Per-request template context shared across every page: current user (if
any), a one-shot flash message, and small RBAC helpers so templates can
gate write controls without importing app.rbac themselves.
"""

from typing import Any

from fastapi import Request

from app import rbac
from app.session import get_session_user, pop_flash


async def build_base_context(request: Request) -> dict[str, Any]:
    user = get_session_user(request)
    role = user.custom_role if user else None
    return {
        "current_user": user,
        "flash": pop_flash(request),
        "can_manage_lists": rbac.can_manage_lists(role),
        "can_manage_cards": rbac.can_manage_cards(role),
        "is_read_only": rbac.is_read_only(role),
        "role_label": rbac.role_label(role),
    }
