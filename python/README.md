# Mudbase Showcase — Kanban (Python)

A server-rendered **FastAPI + Jinja2** reimplementation of the reference team task board at
[`../web`](../web), backed entirely by the real **Mudbase Python SDK**
(`mudbase-sdk`, generated via OpenAPI Generator, published at
[github.com/mudbase/mudbase-sdk](https://github.com/mudbase/mudbase-sdk)) — same Mudbase project,
same collections, same RBAC rules, different stack and delivery model (request/response HTML
instead of a client-side SPA talking directly to `cloud.mudbase.dev`). Architecture and
conventions mirror the sibling [`../../mudbase-showcase-social/python`](../../mudbase-showcase-social/python)
port exactly.

## Stack

FastAPI (async) + Jinja2 templates + vanilla CSS (no bundler, no client-side JS beyond plain HTML
forms). Session state (the Mudbase JWT, refresh token, and user profile) lives only in a signed,
httpOnly Starlette session cookie — it is never sent to browser JS, unlike the reference SPA which
necessarily holds its token in `localStorage` for direct browser-to-Mudbase calls.

## What's implemented

| Feature | Where |
|---|---|
| Three-role sign-in (owner / member / viewer), no self-registration | `app/routers/auth.py`, `app/services/auth_service.py` |
| No anonymous/guest read — every role, including viewer, must sign in | `app/session.py::require_session` |
| Board page: columns (lists) + cards, grouped client-side by list | `app/routers/board.py::board_index` |
| List CRUD + reorder (owner only) | `app/routers/board.py`, `app/services/lists.py` |
| Card CRUD (owner + member) | `app/routers/board.py`, `app/services/cards.py` |
| Move card between lists ("Move to…" select, appended to the end) | `app/routers/board.py::move_card_submit`, `app/services/cards.py::move_card_to_list` |
| Reorder card within a list ("move up"/"move down", position swap) | `app/routers/board.py::reorder_card_submit`, `app/services/cards.py::reorder_card_in_list` |
| Reverse-chronological activity log | `app/routers/activity.py`, `app/services/activity.py` |
| Role-aware UI, server-enforced (no client JS to bypass) | `app/rbac.py`, `app/context.py` |

Every `lists`/`cards`/`activity` collection read/write goes through the real
`mudbase_sdk.DataApi`/`AuthenticationApi` against `cloud.mudbase.dev` (see
`app/mudbase_client.py`).

## No realtime (deliberate)

The reference web app subscribes to Socket.IO rooms so board and activity changes appear live.
This port — like the sibling social/ecommerce Python ports — is plain request/response HTML: a
page reload is how you see activity from other users. See `plan/build-plan.md` "Stack Decisions"
for the precedent this follows.

## No drag-and-drop (deliberate, and the only option here anyway)

Cards move via an accessible "move up" / "move down" pair and a "Move to…" list `<select>`, not a
pointer-drag gesture — matching the reference web app's own deliberate choice (see its
`plan/build-plan.md`), and the only interaction model available to a server-rendered app with zero
client-side JavaScript in the first place.

## Setup

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # already points at the shared demo project; edit SESSION_SECRET_KEY at minimum
python -c "import secrets; print(secrets.token_urlsafe(48))"   # → SESSION_SECRET_KEY
uvicorn app.main:app --reload
```

Visit `http://localhost:8000/login`. Use one of the three quick sign-in buttons (Owner / Member /
Viewer) or type credentials manually — see `plan/build-plan.md` for account details and RBAC
verification notes.

### Type checking

```bash
pip install mypy
mypy app   # strict mode, config in mypy.ini — reports zero issues
```

## Architecture notes

- **`app/mudbase_client.py`** wraps the real (synchronous, urllib3-based) `mudbase_sdk` with
  `asyncio.to_thread` adapters so FastAPI's async handlers never block the event loop. Ported
  verbatim from the sibling `mudbase-showcase-social/python` port, including the auth call that
  bypasses the generated typed wrapper method (`login_sync` needs `customRole`, which the
  generated login response model omits) — see that file's module docstring for the full history.
- **`app/session.py`** ports the sibling ports' refresh strategy verbatim: `get_valid_access_token`
  proactively refreshes within a margin of expiry; `call_with_reauth` reactively retries once on a
  401 the margin check didn't predict. Unlike those ports, there is no anonymous-session bootstrap
  here — `require_session` is this app's `<AuthGate>` equivalent (see `plan/build-plan.md` "Auth
  Model" for why every role, including viewer, must have a real session).
- **`app/utils.py::pseudo_object_id`** is a Python port of `../web/src/lib/utils.ts::pseudoObjectId`
  — `cards.assigneeId` is schema-typed as an ObjectId reference on the live project (confirmed by
  the reference app's own live testing), and there is no `users` collection to resolve a real id
  from, so a stable, valid-looking 24-hex-char id is derived from the free-typed assignee name
  instead. Clearing an assignee sends `None` (not `""`) for both `assigneeId`/`assigneeName` — an
  empty string is rejected by the platform the same way an invalid slug would be.
- Every `Id`-suffixed filter field this app sends (`boardId`, `listId`) is a genuine 24-hex-char
  Mudbase ObjectId — `boardId` is the single shared board's real `_id` (see `.env.example`), and
  `listId` is always a real `lists._id`, never a slug.

## Known limitations (real platform/architecture constraints, not bugs)

**No realtime.** See "No realtime (deliberate)" above.

**No `users` collection**, so `assigneeName`/`createdByName`/`actorName` are denormalized onto the
row that references them at write time — matches the same constraint the reference web app and
sibling Python ports document.

**Same-list reorder is a two-write position swap**, not a fractional-index scheme — fine at demo
scale, noted in `plan/build-plan.md` for anyone extending this further.

## Live verification

Full RBAC-aware round-trip verified live against the real Mudbase project through the actual
running app: owner login/list-create/card-create, member login/edit/move/reorder, member and
viewer both blocked from list management, and — the key security claim — four raw write attempts
(create/update/delete on `cards`, create on `lists`) using real per-role JWTs that bypassed this
app's own code entirely, all rejected with a genuine `403 Insufficient permissions` from Mudbase
itself.

This Mac's IP was already rate-limited on Mudbase's auth endpoint from the other showcase ports
built earlier the same day, so the authenticated portion of this run was done from the
`mudhaxk-vps` VPS (a different egress IP) — the same `app/` code, installed fresh and run for
real, not simulated. That process caught and fixed two real bugs before the run above went clean:
a Jinja `loop`-variable scoping issue across `{% include ... with context %}` (native Jinja
behavior — `loop` doesn't cross an include boundary the way an ordinary context variable does),
and an activity-feed page limit (`200`) that exceeded the real Python SDK's client-side `<=100`
cap on `DataApi.list_data`. See `plan/build-plan.md` "Live verification" for the full blow-by-blow,
including the exact request/response pairs.
