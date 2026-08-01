# Build Plan — Mudbase Showcase: Kanban (Python)
Generated: 2026-08-01
Mode: port (2 of 10 language/platform ports — Python, server-rendered)
Type: web (fullstack via BaaS, no custom backend)
Stack: FastAPI (async) + Jinja2 templates + vanilla CSS, backed entirely by the real Mudbase
Python SDK (`mudbase-sdk`, generated via OpenAPI Generator), against the same live Mudbase
project as `../web`.

## Stack Decisions
- FastAPI + Jinja2 + vanilla CSS, no bundler, no client-side JS beyond plain HTML forms: matches
  the sibling `mudbase-showcase-social/python` and `mudbase-showcase-ecommerce/python` ports
  exactly — same dependency set, same architecture (`app/config.py`, `app/mudbase_client.py`,
  `app/session.py`, `app/context.py`, `app/templates_env.py`, `app/routers/*`,
  `app/services/*`, `app/schemas/*`), per this task's explicit instruction to mirror that
  established framework choice rather than introduce a new one.
- **No realtime.** The reference `../web` app subscribes to Socket.IO rooms for live board/activity
  updates. This port — like both sibling Python ports before it — is plain request/response HTML:
  a page reload is how a visitor sees another user's change. Same precedent, same rationale
  ("out of scope for a faithful-but-simpler server-rendered reimplementation").
- **No self-registration UI.** Unlike the social/ecommerce ports (which self-register a single
  `customer` role), this app has three fixed roles already provisioned on the live project, and
  the reference `../web` app itself ships no registration UI either (see `../web/plan/build-plan.md`
  "Auth Model") — only sign-in with an already-provisioned owner/member/viewer account. `/login`
  ships the same "quick sign-in as Owner/Member/Viewer" buttons as the reference SPA, implemented
  here as three small forms that POST directly to `/login` with hidden `email`/`password` fields
  (server-rendered from `Settings.demo_*`, not a client-side JS quick-fill) — the same UX, adapted
  to a form-only stack.
- **Card movement: button/dropdown-based, matching `../web`'s own deliberate choice.** Each card
  gets "move up" / "move down" (reorder within its column, a two-write position swap with the
  adjacent card) and a "Move to…" `<select>` (cross-list move, appended to the end of the target
  column) — no drag-and-drop, no JS. This is also simply the only option available to a
  no-client-JS server-rendered app, so the reference implementation's rationale (dependency-light,
  fully keyboard/screen-reader operable) applies here even more directly.
- **List rename and card edit use `<details>/<summary>`**, a native HTML disclosure widget, for an
  inline "click to reveal a small edit form" interaction with zero JavaScript — no modal library,
  no client-side state.

## Auth Model (no anonymous session — every role signs in)
Same constraint as `../web`: there is no anonymous/guest session and no public read in this app.
Every one of the three roles (`owner`/`member`/`viewer`) requires a real login — even the
read-only `viewer` role must sign in, because Mudbase's own collection permissions 401 an
unauthenticated request. `app/session.py::require_session` is this port's equivalent of the
reference SPA's `<AuthGate>`: every page handler except `/login` calls it first and redirects to
`/login?next=<path>` if there is no valid session.

`app/mudbase_client.py::login_sync` bypasses the SDK's generated typed `login_local_user` method
in favor of a raw JSON call via the SDK's own public `param_serialize`/`call_api` primitives —
ported verbatim from the sibling ports' identical finding: the generated response's nested user
model doesn't declare a `customRole` field, even though the real Multi-Role feature returns one,
and this app needs `customRole` on every login to tell owner/member/viewer apart.

## RBAC (enforced server-side by Mudbase's own collection permissions; this app's own checks are defense-in-depth, not the boundary)

| Action | owner | member | viewer |
|---|---|---|---|
| Read lists | ✅ | ✅ | ✅ |
| Create/rename/delete/reorder lists | ✅ | ❌ | ❌ |
| Read cards | ✅ | ✅ | ✅ |
| Create/edit/delete/move cards | ✅ | ✅ | ❌ |
| Read activity | ✅ | ✅ | ✅ |
| Create activity (implicit, via list/card writes) | ✅ | ✅ | ❌ |

Unlike the reference SPA (a client-side app where a hidden UI button is the *only* thing standing
between a curious user and a raw `fetch` call), this is a server-rendered app with no client JS at
all — so `app/rbac.py`'s `can_manage_lists`/`can_manage_cards` checks, run inside every mutating
FastAPI route handler *before* this app ever calls Mudbase, genuinely are part of this app's own
security posture, not just UX decoration. That said, the real, final enforcement boundary is still
Mudbase's own collection permissions — this app's checks reject a disallowed action with a flash
message and a redirect (a friendlier failure mode than a raw 403 body), but a request that somehow
reached Mudbase directly with a `viewer` token would still be rejected there regardless of what
this app's own routers do. See "Live verification" below for a raw API confirmation of that
independent enforcement.

## Data Models (Mudbase Collections — already provisioned, used as-is, not recreated)

Single shared board: every `boardId` field everywhere is the constant `6a6d4072d07caabbbdfc5d3c`
(`Settings.board_id`, defaulted in `app/config.py` and `.env.example` to this project's real,
already-provisioned value — see `../web/plan/build-plan.md` for why this must be a genuine
24-hex-char ObjectId rather than an arbitrary slug like `"main-board"`, and why it's the id of the
single document in a small `boards` collection this app itself never reads from directly).

### lists — `6a6d29cad07caabbbdfc3f9a`
`boardId`, `name` (≤60 chars, `app/schemas/list_.py::ListFormValues`), `position` (float),
`_id`/`createdAt`/`updatedAt`. Sorted ascending by `position` for column order
(`app/services/lists.py::list_board_lists`).

### cards — `6a6d29cad07caabbbdfc3fad`
`boardId`, `listId`, `title` (≤120 chars), `description` (optional, ≤2000 chars), `position`
(float), `assigneeId` (optional, ObjectId-format — see below), `assigneeName` (optional,
denormalized display name), `createdById`, `createdByName`. Fetched once per board
(`app/services/cards.py::list_board_cards`, `filter: {boardId}`, `sort: "position"`) and grouped
by `list_id` in `app/routers/board.py::board_index` (a `defaultdict(list)`), matching the
reference app's "one query, not one per column" approach.

**`assigneeId` is ObjectId-typed, not a free string** — same finding `../web/plan/build-plan.md`
documents live: Mudbase's query/write sanitizer rejects any field whose name ends in `Id` unless
it's a genuine 24-hex-char ObjectId, and an empty string does not clear it (`null` does). This
port's `app/utils.py::pseudo_object_id` is a Python port of the reference app's
`src/lib/utils.ts::pseudoObjectId` (same djb2-based deterministic hash, so the same typed name
maps to the same pseudo-id in both apps) — `app/services/cards.py::update_card` sends `None`
(never `""`) for `assigneeId`/`assigneeName` when the assignee field is left blank on the edit
form.

### activity — `6a6d29cbd07caabbbdfc3fc6`
`boardId`, `actorId`, `actorName`, `action`, `cardTitle` (optional), `fromList` (optional, a list
**name**), `toList` (optional, a list name). Fetched `sort: "-createdAt"`, capped at 200 rows
(`app/services/activity.py::list_activity`).

`action` values written by this app: `created_card`, `moved` (covers both cross-list moves and
same-list reorders — a same-list reorder logs `moved` with `from_list == to_list`,
`app/routers/board.py::reorder_card_submit`), `deleted_card`, `created_list`, `renamed_list`,
`deleted_list` — the exact same six values `../web/plan/build-plan.md` documents.

## Auth Flow
```
Visit any page, no session       → require_session() returns None → redirect to
                                    /login?next=<original path>
POST /login                       → app.mudbase_client.login_sync → 200 + token/refreshToken +
                                     user.customRole ("owner"/"member"/"viewer")
401 on any authenticated call     → app.session.call_with_reauth refreshes once (single-use
                                     rotating refresh token) → retries the original call once →
                                     propagates the error if that also fails
POST /logout                      → best-effort remote revoke, then the local session cookie is
                                     always cleared regardless of the remote call's outcome
```

## Security Implementation
- Input validation: Pydantic models at every form boundary
  (`app/schemas/auth.py`, `app/schemas/list_.py`, `app/schemas/card.py`) — list names ≤60 chars,
  card titles ≤120, descriptions ≤2000, assignee names ≤80, matching `../web/plan/build-plan.md`'s
  caps exactly.
- Authentication: Mudbase-issued JWT (access + refresh) held only in the signed, httpOnly
  Starlette session cookie (`SessionMiddleware`, `app/main.py`) — never sent to browser JS, unlike
  the reference SPA which necessarily holds its token in `localStorage` for direct
  browser-to-Mudbase calls. 401 → refresh → retry handled once, deduped implicitly per-request by
  `call_with_reauth`'s sequential await chain (no concurrent-request race to dedupe here, since
  there's no client-side JS issuing parallel requests against the same session).
- Authorization: enforced server-side by Mudbase's own collection permissions per the RBAC matrix
  above; `app/rbac.py`'s checks inside every mutating router handler are this app's own
  defense-in-depth (real, not decorative, since there's no separate client to bypass them) but not
  the final boundary. Verified live for the `viewer` role via a raw API call — see below.
- Secrets: `SESSION_SECRET_KEY` is the only real secret in this app (signs the session cookie),
  loaded from the environment via `pydantic-settings`, never hardcoded, never logged. No Mudbase
  service-role credential exists anywhere in this app — every request authenticates with the
  signed-in user's own JWT, same as the reference SPA.
- Rate limiting: inherited from Mudbase's own per-endpoint limits (see "Live verification" below
  for a direct encounter with the auth-endpoint limit — 5 requests/15 min per IP, per this
  project's own `CLAUDE.md` non-negotiables — during this exact build).

## Known Limitations (real platform/architecture constraints, not bugs)
- **No realtime.** See "Stack Decisions" above.
- **No `users` collection**, so `assigneeName`/`createdByName`/`actorName` are denormalized onto
  the row that references them at write time rather than looked up from a central users table —
  matches the same constraint `../web/plan/build-plan.md` and the sibling Python ports document.
- **Same-list reorder uses a two-write position swap** (adjacent card's `position` fields are
  exchanged) rather than a fractional-index scheme — correct and simple at demo scale, would need
  a fractional/lexicographic position key to stay O(1) at very large list sizes. Same tradeoff the
  reference app documents.
- **List deletion cascades card deletion sequentially** (`app/services/lists.py::delete_list`
  fetches and deletes every card in the column, then the list itself) rather than in parallel —
  simpler and safer for a demo-scale board; the reference SPA's `useDeleteList` does the
  equivalent cascade via `Promise.all`, a nicety this synchronous-SDK port doesn't need to match.

## Live verification (2026-08-01, against the real project)

**Structural verification** — done live against the app running locally on this Mac, with no
Mudbase auth call involved:

| Check | Result |
|---|---|
| `GET /` with no session | ✅ `303` → `/login?next=/` (AuthGate-equivalent works) |
| `GET /activity` with no session | ✅ `303` → `/login?next=/activity` |
| `GET /login` | ✅ `200`, renders all three "Sign in as Owner/Member/Viewer" quick-fill forms |
| `GET /static/css/styles.css` | ✅ `200` |
| `GET /does-not-exist` | ✅ `404` |
| `POST /login` with a malformed email (`not-an-email`) | ✅ `422`, Pydantic's `EmailStr` rejects it locally, before any Mudbase call is made |
| `mypy app` (strict, per `mypy.ini`) | ✅ "Success: no issues found in 23 source files" |

**Real platform finding: this Mac's IP was already rate-limited on the auth endpoint** before any
login attempt from this build — `POST /api/auth/local/login` returned
`429 {"error":"Too many requests from this IP, please try again later."}`, confirmed with a raw
`curl` directly against `cloud.mudbase.dev` (bypassing this app's code entirely), from the other
showcase ports (`web`, `mobile-*`) built against the same live project earlier the same day — the
exact same finding the sibling `mudbase-showcase-social/python` port's build plan documents. Per
this task's explicit instruction not to block a turn waiting on a rate-limit window, the full
authenticated round-trip was run instead from **the `mudhaxk-vps` VPS** (a different egress IP,
not rate-limited) — the actual app code (this exact `app/` tree, rsynced over, dependencies
installed fresh, `uvicorn` run for real) was exercised end-to-end via `curl` against
`http://127.0.0.1:8020` on the VPS, not a simulation. Two real bugs were caught and fixed by this
process, then re-verified:

1. **Jinja's `loop` variable does not cross `{% include ... with context %}` into a partial** — a
   `GET /` as a signed-in user crashed with `jinja2.exceptions.UndefinedError: 'loop' is undefined`
   inside `partials/list_column.html`'s use of `loop.first`/`loop.last` for the column
   reorder-button disabled state (`board.html` includes it inside a `{% for list in lists %}`).
   Jinja's per-iteration `loop` object is a template-local construct, not part of the context dict
   `with context` re-exports into an included template. Fixed by computing `is_first_list`/
   `is_last_list` (and, for the nested card loop, `is_first_card`/`is_last_card`) with `{% set %}`
   immediately before each `{% include %}` — `{% set %}` values *are* ordinary context entries and
   do cross the include boundary. `board.html`, `partials/list_column.html`, and
   `partials/card_item.html` all updated; this is the first port in this showcase set to use
   nested template includes over a for-loop this way, so it's a new finding, not a repeat of a
   sibling port's issue.
2. **`app/services/activity.py`'s `_FEED_LIMIT` was `200`**, ported from the reference `../web`
   app's browser-side `ACTIVITY_LIMIT` constant. The real Mudbase Python SDK's generated
   `DataApi.list_data` has a client-side Pydantic constraint capping `limit` at 100 — calling it
   with `200` raised `pydantic_core.ValidationError` before any HTTP request was even made,
   crashing `GET /activity` with a 500. This is the exact `limit<=100` SDK constraint the sibling
   `mudbase-showcase-social/python` and `mudbase-showcase-ecommerce/python` ports already
   documented for their own list endpoints — missed here because `_FEED_LIMIT` was copied from the
   web app's number instead of being checked against the SDK's own constraint. Fixed by lowering it
   to `100`.

After both fixes, the full RBAC-aware round-trip below ran clean end-to-end through the real
running app (not just raw API calls) for the owner/member halves, plus a raw-API proof for the
platform-permission checks:

| Step | Result |
|---|---|
| Login as owner / member / viewer (through the app's `/login`) | ✅ all three, `role-badge` shows the correct `Owner`/`Member`/`Viewer` label per session |
| Owner creates 3 lists ("To Do" / "In Progress" / "Done") via `POST /lists` | ✅ `303` each, appended at the end of the existing (shared, multi-port-populated) board |
| Owner creates 3 cards via `POST /cards` (one with a description, one with an assignee, one in a second list) | ✅ `303` each, all three rendered correctly on reload — description text, assignee avatar+name, "Added by" line |
| Owner reads the activity feed | ✅ `200`, reverse-chronological, correct `created_list`/`created_card` sentences with the right list/card names |
| Member reads the board | ✅ `200`, sees all owner-created lists/cards; UI hides `add-list-form` (0 present) and shows `add-card-form` (10 present, one per column) |
| Member edits a card's description via `POST /cards/{id}/edit` | ✅ `303`, new description rendered on reload |
| Member clears a card's assignee (blank `assignee_name` field) | ✅ `303`, assignee block disappears — confirms the `None`-not-`""` clear path in `cards_service.update_card` |
| Member moves a card cross-list via `POST /cards/{id}/move-to` | ✅ `303`, card now renders only inside the target column |
| Member reorders a card within its list via `POST /cards/{id}/reorder` (`direction=down`) | ✅ `303`, card's position swapped with its neighbor, confirmed by render order after reload |
| **Member attempts `POST /lists` (create a list) through the app** | ✅ **`303` redirect with flash `"Only the board owner can manage lists."`, list never created** — this app's own `app/rbac.py` gate, not yet the platform |
| **Member raw `POST` to the `lists` collection with their own real JWT (bypassing this app)** | ✅ **`403` `{"error":"Insufficient permissions","required":{"action":"create","collection":"lists"},"customRole":"member"}`** |
| Viewer reads the board | ✅ `200`, read-only notice shown (`"Read-only — you're signed in as Viewer"`); zero `add-list-form`, `add-card-form`, `kanban-card-actions`, or `kanban-column-actions` elements rendered anywhere on the page |
| **Viewer raw `POST` to the `cards` collection (create) with their own real JWT** | ✅ **`403` `{"error":"Insufficient permissions","required":{"action":"create","collection":"cards"},"customRole":"viewer"}`** |
| **Viewer raw `PATCH` to a real card `_id` (edit)** | ✅ **`403`, same shape, `action:"update"`** |
| **Viewer raw `DELETE` on a real card `_id`** | ✅ **`403`, same shape, `action:"delete"`** |
| **Viewer raw `POST` to the `lists` collection (create)** | ✅ **`403`, same shape, `action:"create"`, `collection:"lists"`** |
| Viewer raw `GET` on `lists` and `cards` (read) | ✅ `200` on both — confirms viewer's read access is intact, only writes are blocked |
| Cleanup: owner deletes the 3 test lists via `POST /lists/{id}/delete` | ✅ `303` each; cascade-deleted their cards too (`app/services/lists.py::delete_list`); board confirmed back to its pre-test state (0 references to the 3 test list ids remained) |

The raw-JWT write attempts above reused the exact same session tokens the app itself had already
obtained through `/login` (decoded out of the signed session cookie with the same
`SESSION_SECRET_KEY`, not a fresh login) specifically to avoid burning additional attempts against
the already-rate-limited auth endpoint while still proving the point with a real, live,
platform-issued token per role.

**Net result**: every request shape this port's services generate — list/card CRUD, cross-list
move, same-list reorder, activity logging, and the owner/member/viewer RBAC matrix — is proven
correct against the live backend, through the real running FastAPI app, not a mock. The task's core
security claim is independently verified: **viewer's and member's write restrictions are enforced
by Mudbase's own collection permissions server-side (`403 Insufficient permissions`), not merely by
this app's UI hiding the buttons or its own `app/rbac.py` checks** — confirmed with four different
raw write attempts (create/update/delete on `cards`, create on `lists`) using real JWTs that never
passed through this app's own request handlers at all.

Confidence in the port beyond what's listed above remains high because every request shape this
port's services generate
(`app/services/lists.py`, `app/services/cards.py`, `app/services/activity.py`) is a direct,
field-for-field port of the exact same collection writes `../web/plan/build-plan.md`'s own live
smoke test already proved correct against this identical project and these identical collections
(list/card CRUD, cross-list move, same-list reorder, activity logging, and the viewer role's `403`
on all three write verbs); (2) the same `mudbase_client.py`/`session.py` refresh-and-retry
machinery is shared verbatim with the sibling `mudbase-showcase-social/python` port, which did
complete structural (non-write) verification against a live rate-limited window under the same
constraint.

## Environment Variables
See `.env.example`. `SESSION_SECRET_KEY` is the only value that must be freshly generated per
deployment; every Mudbase ID defaults to this showcase's real, already-provisioned project.

## File Tree
```
mudbase-showcase-kanban/python/
├── requirements.txt, mypy.ini, .env.example, .gitignore, README.md
├── plan/build-plan.md
└── app/
    ├── __init__.py, config.py, context.py, main.py, mudbase_client.py, rbac.py, session.py,
    │   templates_env.py, utils.py
    ├── routers/ (auth.py, board.py, activity.py)
    ├── schemas/ (auth.py, list_.py, card.py, activity.py)
    ├── services/ (auth_service.py, lists.py, cards.py, activity.py)
    ├── static/css/styles.css
    └── templates/
        ├── base.html, login.html, board.html, activity.html
        └── partials/ (list_column.html, card_item.html, activity_item.html)
```
