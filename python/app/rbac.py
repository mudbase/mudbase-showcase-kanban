"""Server-side mirror of ../web/src/lib/rbac.ts.

Unlike a client-side SPA, this app's role checks *are* part of the security
boundary that stands between an end user and Mudbase — there is no browser
JS to "just hide a button" here, every write goes through one of these
gates before this app's own request handler ever calls Mudbase. That said,
Mudbase's own collection permissions remain the ultimate enforcement layer
(see plan/build-plan.md "Live smoke test results" for a raw write attempt
that bypasses this app's routers entirely) — these functions are this
app's own defense-in-depth check, not a replacement for it.
"""

_MANAGE_LISTS_ROLES = frozenset({"owner"})
_MANAGE_CARDS_ROLES = frozenset({"owner", "member"})
_KNOWN_ROLES = frozenset({"owner", "member", "viewer"})

_ROLE_LABELS = {"owner": "Owner", "member": "Member", "viewer": "Viewer"}


def can_manage_lists(role: str | None) -> bool:
    return role in _MANAGE_LISTS_ROLES


def can_manage_cards(role: str | None) -> bool:
    return role in _MANAGE_CARDS_ROLES


def is_read_only(role: str | None) -> bool:
    return not can_manage_cards(role)


def is_known_role(role: str | None) -> bool:
    return role in _KNOWN_ROLES


def role_label(role: str | None) -> str:
    return _ROLE_LABELS.get(role or "", "Unknown")
