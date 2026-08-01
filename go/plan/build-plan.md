# Build Plan — Mudbase Showcase: Kanban (Go)

Generated: 2026-08-01
Mode: port (Go server-rendered reimplementation of the reference Next.js app in `../web`)
Type: web (fullstack via BaaS, no custom backend)
Stack: Go 1.26 + `net/http` + `chi/v5` + `html/template` + `gorilla/sessions`, backed entirely by
Mudbase (`cloud.mudbase.dev`), against the official Mudbase Go SDK
(`github.com/mudbase/mudbase-sdk/go`).

## Stack Decisions

- Framework (net/http + chi + `html/template`, cookie-based session, the 401 -> refresh -> retry
  pattern via request context) matches `mudbase-showcase-social/go` exactly - that sibling port's
  `internal/mbase` package (client, auth, data, errors, refresh) is ported here nearly verbatim,
  trimmed to what this app needs: no anonymous/guest session, no self-registration.
- No custom backend of any kind: every persistence, auth, and RBAC concern is a real Mudbase
  REST call made with the signed-in visitor's own JWT, held only in an encrypted, httpOnly session
  cookie (no client-side JS framework, no JWT ever reaches the browser as a readable value).
- **Card movement: button/dropdown-based, not drag-and-drop** - "move up"/"move down" (reorder
  within a list) and a "Move to..." `<select>` (cross-list move to the end of the target list),
  same interaction model as the reference web app's deliberate `MoveCardControl`/`CardItem`
  choice (see `../web/plan/build-plan.md` "Stack Decisions"). Every move still writes
  `position`/`listId` and appends an `activity` row exactly as specified.
- **Zero-JS-required editing via native `<details>`/`<summary>` disclosure widgets.** Renaming a
  list, editing a card, and adding a card/list all use a `<details>` popover form instead of a
  client-side modal (the reference web app's shadcn `Dialog`) - fully keyboard- and
  screen-reader-operable with no JavaScript framework, matching this port's zero-custom-backend,
  zero-SPA-framework constraint. The only JavaScript in this app is the two poll-refresh
  `<script>` blocks (board and activity pages), which explicitly skip replacing the DOM while an
  edit popover is open (`details[open]`) so an in-progress edit is never wiped mid-keystroke.
- **Polling instead of a push realtime subscription.** There is no official Mudbase Go realtime
  (Socket.IO) client - `/board/fragment` and `/activity/fragment` are polled every 4 seconds by a
  small inline script, the same tradeoff `mudbase-showcase-social/go` documents.

## Auth Model

Identical to the reference web app: **no anonymous/guest session and no public read.** Every one
of the three roles (`owner`/`member`/`viewer`) requires a real login - even the read-only
`viewer` role must sign in, because Mudbase's own collection permissions 401 an unauthenticated
request. `sessionMiddleware` (`internal/server/middleware.go`) therefore never establishes a guest
session (unlike the sibling social port); a visitor with no cookie simply proceeds signed-out and
is redirected to `/login` by `requireSignedIn` on any route that needs an identity.

Only `Login`/`Logout`/`Refresh` exist in `internal/mbase/auth.go` - no registration UI, matching
the reference web app and the task's instruction to use the three pre-provisioned demo accounts
rather than register new ones:

- Owner: `kanban.owner.demo@gmail.com` / `KanbanTest123!`
- Member: `kanban.member.demo@gmail.com` / `KanbanTest123!`
- Viewer: `kanban.viewer.demo@gmail.com` / `KanbanTest123!`

`/login` ships the same three "quick-fill" buttons as the reference web app's `LoginForm.tsx`
(here, plain `<form>`s with hidden `email`/`password` inputs - no client JS needed) alongside a
manual email+password form.

## RBAC Matrix (enforced server-side by Mudbase's own collection permissions; this app's own
`internal/rbac` + `requireRole` middleware mirror it for defense-in-depth, per the task's
"server-side enforcement, don't rely on UI-only gating" requirement)

| Action | owner | member | viewer |
|---|---|---|---|
| Read lists | Y | Y | Y |
| Create/rename/delete/reorder lists | Y | N | N |
| Read cards | Y | Y | Y |
| Create/edit/delete/move cards | Y | Y | N |
| Read activity | Y | Y | Y |
| Create activity (implicit, via card/list writes) | Y | Y | N |

This app enforces the matrix **twice, independently**:

1. **Route-level middleware** (`internal/server/middleware.go`'s `requireListManager` /
   `requireCardManager`, wired in `app.go`'s `Routes()`): every list-mutating route requires
   `rbac.CanManageLists(role)`, every card-mutating route requires `rbac.CanManageCards(role)`.
   A request that fails this check never reaches a handler, let alone Mudbase - it's redirected
   back to `/` with a `?error=` flash.
2. **Mudbase's own collection permissions** (the real, load-bearing enforcement boundary): even if
   (1) were removed or buggy, the exact same write is independently rejected server-side with a
   `403 {"error":"Insufficient permissions"}` - verified live with a raw `curl` write attempt as
   the viewer role bypassing this app's UI and route gate entirely (see "Live smoke test results").
   `internal/mbase/errors.go`'s `IsForbidden` + `handlers_lists.go`'s `mutationError` map that 403
   to an honest "the server rejected this action" message rather than a generic 500.

Templates also hide write controls a role cannot use (`CanManageLists`/`CanManageCards`/`ReadOnly`
computed once in `internal/server/view.go`'s `buildBoardView` and denormalized onto every list/card
view) - this is UX polish, not a third enforcement layer; removing it would not open any write path
that (1) and (2) don't already close.

## Data Models (Mudbase Collections - already provisioned, used as-is, not recreated)

Single shared board: every `boardId` field everywhere is the constant
`6a6d4072d07caabbbdfc5d3c` (`MUDBASE_BOARD_ID`) - the id of the one document in the `boards`
collection (`6a6d405cd07caabbbdfc5c79`) the reference web app's build plan documents provisioning
after discovering `boardId` is ObjectId-typed, not a free string. This Go port does not read the
`boards` collection either (same as the reference app) - `BOARD_ID` is just a real, valid,
pre-existing ObjectId used as a constant scope value.

### lists - `6a6d29cad07caabbbdfc3f9a`
`boardId`, `name`, `position` (`internal/models/list.go`). Sorted ascending by `position` for
column order (`internal/store/lists.go`'s `All`).

### cards - `6a6d29cad07caabbbdfc3fad`
`boardId`, `listId`, `title`, `description`, `position`, `assigneeId`/`assigneeName` (both
pointers - `null` is a real, distinct wire value from "never set", see `internal/models/card.go`),
`createdById`, `createdByName` (`internal/models/card.go`). Fetched once per board request
(`filter: {boardId}`, `sort: "position"`) and grouped server-side by `listId`
(`internal/server/view.go`'s `buildBoardView`) - one query, not one per column.

### activity - `6a6d29cbd07caabbbdfc3fc6`
`boardId`, `actorId`, `actorName`, `action`, `cardTitle`/`fromList`/`toList` (all optional -
`internal/models/activity.go`). Fetched `sort: "-createdAt"`, limit 200
(`internal/store/activity.go`'s `Feed`) for the reverse-chronological feed.

`action` values this app writes (`internal/models.ActivityAction`): `created_card`, `moved`
(covers both cross-list moves and same-list reorders, `fromList == toList` on a reorder),
`deleted_card`, `created_list`, `renamed_list`, `deleted_list` - identical set to the reference web
app, written from the same owner/member-gated `internal/store` methods that perform the underlying
mutation, so a handler can never forget to log an action.

### `assigneeId` pseudo-ObjectId derivation

There is no `users` collection (see "Known Limitations"). An assignee is a free-typed name; Mudbase
validates `cards.assigneeId` as an ObjectId reference server-side, so `internal/store/pseudoid.go`
ports the reference web app's `pseudoObjectId()` (`../web/src/lib/utils.ts`) bit-for-bit (the same
djb2 hash, the same `"{name}:{round}"` seeding, the same 24-hex-char truncation) so the same typed
name always derives the same id and never fails the format check. Clearing an assignee sends
explicit JSON `null` for both `assigneeId` and `assigneeName` (never `""`, which fails the same
ObjectId format check) - see `internal/store/cards.go`'s `Update`.

## Auth Flow

```
Visit any page, no session cookie  -> requireSignedIn redirects to /login (no anonymous/guest
                                       session - every role, including viewer, must authenticate)
Login                                -> POST /api/auth/local/login {email, password, projectId}
                                                     -> 200 + token/refreshToken + user.customRole
                                                        (one of "owner"/"member"/"viewer")
401 on any authenticated call        -> mbase.callWithRefresh refreshes once (via the
                                         TokenRefresher wired into request context by
                                         sessionMiddleware) -> retries the original request once
                                         -> surfaces the error if that also fails
403 on any authenticated call        -> surfaced as-is (mbase.IsForbidden) - no refresh could ever
                                         fix a permissions rejection; mapped to an honest message
                                         by handlers_lists.go/handlers_cards.go's mutationError
Logout                                -> POST /api/auth/logout (revokes token), session cookie
                                          cleared
```

## UI Pages

- `/login` - email+password form plus three "quick-fill" role buttons (`templates/login.html`).
- `/` - the board: header (title, read-only notice for viewers), every list/column and its cards,
  an owner-only "add list" popover at the end of the row (`templates/board.html` +
  `templates/partials.html`'s `board_body`/`list_column`/`card_item`).
- `/board/fragment` - poll target for the board body (no layout), refreshed every 4s.
- `/activity` - full reverse-chronological activity feed (`templates/activity.html`).
- `/activity/fragment` - poll target for the activity list, refreshed every 4s.

## Security Implementation

- Input validation: every form handler trims and length-caps its inputs server-side
  (`internal/server/handlers_lists.go`/`handlers_cards.go` - list names at 60 chars, card titles at
  120, descriptions at 2000, assignee names at 80 - matching the reference web app's zod schemas)
  before ever calling Mudbase. There is no client-side-only validation path in this app; every page
  is server-rendered and every write is a real POST handled server-side.
- Authentication: Mudbase-issued JWT (access + refresh) held only in an encrypted, httpOnly,
  `SameSite=Lax` session cookie (`internal/session`) - never sent to the browser as
  JavaScript-readable state. 401 -> refresh -> retry handled once via request context
  (`internal/mbase/refresh.go`).
- Authorization: enforced twice - this app's own `requireListManager`/`requireCardManager`
  middleware (route-level, before any Mudbase call) and Mudbase's own collection permissions
  (the real boundary) - see "RBAC Matrix" above and the live smoke test below.
- Secrets: `SESSION_SECRET` is the only real secret in this app (signs/encrypts the session
  cookie) - every Mudbase collection/project ID is a plain, non-secret identifier. No API key or
  service-role credential exists anywhere in this codebase.

## Live Smoke Test Results (2026-08-01, against the real project)

Performed with the three real, pre-verified demo accounts (`kanban.owner.demo@gmail.com`, session
display name "Olivia Owner"; `kanban.member.demo@gmail.com`, "Max Member";
`kanban.viewer.demo@gmail.com`, "Vera Viewer" - all password `KanbanTest123!`) against the real
project (`6a6d29b2d07caabbbdfc3f8c`) and the real, already-seeded board
(`6a6d4072d07caabbbdfc5d3c`). Run both through this app's own server (a local built binary on
`127.0.0.1:8137`, driven with `curl` carrying a real per-role cookie jar) and, separately, with a
direct `curl` straight against `cloud.mudbase.dev` using a freshly-issued viewer JWT - bypassing
this app's routes, session, and middleware entirely.

**Note on the account names above**: this is a single shared demo project that every one of the 10
concurrently-built language/platform ports in this showcase logs into with the exact same three
email addresses. The activity feed is genuinely global (`boardId`-scoped, not per-port), so
entries and even display names from other ports' simultaneous test runs interleave with this run's
own - e.g. this run's own actions are attributed to "Olivia Owner"/"Max Member"/"Vera Viewer", but
other entries in the same feed during this window show different names ("Kanban Owner", "Mia
Member") from sibling ports' own runs. This is expected shared-infrastructure noise, not a bug -
every result below was verified by checking the actual document state (list membership, card
fields) returned to *this run's own session*, not by trusting activity-feed text in isolation.

**Note on the platform's auth rate limit**: `POST /api/auth/local/login` is limited to 5
requests/15min per IP (see `../web/plan/build-plan.md`), shared across all 10 concurrently-running
sibling-port builds on this same machine/IP. Every login below (owner, member, viewer, and the
final raw-bypass viewer re-login) initially hit `429 Too many requests` and required waiting
several minutes with periodic retries before succeeding - a platform characteristic, not an app bug.

| Step | Result |
|---|---|
| `go build ./...` / `go vet ./...` / `gofmt -l .` | clean |
| Unauthenticated `GET /`, `GET /activity`, `POST /lists` | all `303` -> `/login?redirect=...` (requireSignedIn gate works before any handler runs) |
| Owner logs in via `/login` | `303` -> `/`, board renders, role badge "Owner" |
| Owner creates 3 lists ("To Do", "In Progress", "Done") | each `303` -> all 3 appear at the end of the row, correct position order |
| Owner creates 2 cards in "To Do" (one with a description, one with an assignee "Ben Chen") | both `303` -> cards appear, description renders, assignee avatar initials "BC" + name render |
| Owner creates 1 card in "In Progress" | `303` -> appears in that column |
| Owner edits a card (new title/description, clears assignee) | `303` -> updated fields render; confirmed **no** new activity row was written (matches reference `useUpdateCard`) |
| Activity feed after the above | shows `created_list` x3 and `created_card` x3 in correct reverse-chronological order, correct actor name, correct `toList` |
| Member logs in | board renders, role badge "Member" |
| Member moves a card "To Do" -> "In Progress" via `POST /cards/:id/move` | `303` -> card's own document now shows the new `listId`; confirmed by locating the card inside the "In Progress" column's rendered HTML afterward |
| Member reorders that card up within "In Progress" (`POST /cards/:id/reorder`) | `303` -> position swap confirmed (card now renders before its former predecessor) |
| Member deletes a card | `303` -> card removed from the board; activity feed shows `Max Member deleted card "..." from In Progress` |
| **Member attempts `POST /lists` (create list) through this app** | `303` -> `/?error=Only+the+board+owner+can+manage+lists.` - blocked by `requireListManager` before any Mudbase call |
| Viewer logs in | board renders **read-only**: `grep` for `Add list`, `add-card-summary`, `card-item-actions`, `card-move-row` all return **0 matches** - zero write controls rendered; read-only notice "Read-only — you're signed in as Viewer" shown |
| Viewer reads `/activity` | `200`, full log visible (49 entries) |
| **Viewer attempts `POST /cards` (create) through this app** | `303` -> `/?error=Viewers+can%27t+modify+cards+on+this+board.` - blocked by `requireCardManager` |
| **Viewer attempts `POST /lists` (create) through this app** | `303` -> `/?error=Only+the+board+owner+can+manage+lists.` |
| **Raw `curl POST` directly against `cloud.mudbase.dev`'s `cards` collection with a freshly-issued viewer JWT (bypassing this app's routes/session/middleware entirely)** | `403 {"error":"Insufficient permissions","required":{"action":"create","collection":"cards"},"userRole":"viewer","customRole":"viewer"}` |
| **Raw `curl PATCH .../cards/:id` with the same raw viewer JWT** | `403 {"error":"Insufficient permissions","required":{"action":"update","collection":"cards"},"userRole":"viewer","customRole":"viewer"}` |
| **Raw `curl DELETE .../cards/:id` with the same raw viewer JWT** | `403 {"error":"Insufficient permissions","required":{"action":"delete","collection":"cards"},"userRole":"viewer","customRole":"viewer"}` |
| Raw `curl GET .../lists` with the same raw viewer JWT (read, for contrast) | `200`, 7 lists returned (shared board across all sibling ports) |
| Owner deletes the "To Do" list, which still had 1 card in it | `303` -> both the list and its remaining card are gone from the rendered board; activity feed shows `Olivia Owner deleted list "To Do"` - cascade confirmed |
| `/board/fragment`, `/activity/fragment` (poll endpoints) | both `200`, correct partial HTML, no `<html>`/layout wrapper |

**Net result**: every feature this port implements - list CRUD (owner-only), card CRUD (owner or
member), cross-list move, same-list reorder with activity logging, and RBAC enforcement - is
proven correct against the real, live Mudbase backend. The task's core security claim is
independently verified with a **raw `curl` write attempt against `cloud.mudbase.dev` directly**,
using a freshly-issued viewer JWT that never touched this app's routes, session, or
`requireRole` middleware at all: **Mudbase's own collection permissions reject the viewer role's
create/update/delete attempts server-side with a real `403 Insufficient permissions` on all
three verbs, while the same token's read requests succeed** - this app's own middleware and
template button-hiding are UX/defense-in-depth on top of that real, independent boundary, not a
substitute for it.

## Known Limitations (real platform constraints, not bugs - same ones the reference web app and
sibling Go ports document)

- **No `users` collection.** Assignee/creator/actor display names are denormalized onto the row
  that references them at write time (`assigneeName`, `createdByName`, `actorName`).
- **Same-list reorder is a two-write position swap**, not a fractional-index scheme - correct and
  simple at demo scale, would need a fractional/lexicographic position key at very large list
  sizes (matches the reference web app's own documented limitation).
- **Polling instead of push realtime** - no official Mudbase Go realtime (Socket.IO) client exists;
  `/board/fragment` and `/activity/fragment` are polled every 4 seconds instead, functionally
  equivalent for this demo (matches `mudbase-showcase-social/go`'s documented tradeoff).
- **Zero-JS editing via `<details>`/`<summary>`, not a modal dialog** - a deliberate simplification
  for a server-rendered app with no SPA framework; the poll scripts explicitly skip replacing the
  DOM while any `<details open>` popover is on screen so an in-progress edit is never wiped.

## Environment Variables

See `.env.example`. `SESSION_SECRET` is the only real secret; every Mudbase ID is a plain,
non-secret identifier.

## File Tree

```
mudbase-showcase-kanban/go/
├── .env.example, .gitignore, go.mod, go.sum, README.md
├── plan/build-plan.md
├── cmd/server/main.go
└── internal/
    ├── config/config.go
    ├── mbase/ (client.go, auth.go, data.go, errors.go, refresh.go)
    ├── models/ (list.go, card.go, activity.go)
    ├── rbac/rbac.go
    ├── session/session.go
    ├── store/ (lists.go, cards.go, activity.go, pseudoid.go)
    └── server/
        ├── app.go, context.go, middleware.go, templates.go, view.go, format.go, helpers.go,
        │   activity_text.go
        ├── handlers_auth.go, handlers_board.go, handlers_lists.go, handlers_cards.go,
        │   handlers_activity.go
        ├── templates/ (layout.html, partials.html, board.html, board_fragment.html,
        │               activity.html, activity_fragment.html, login.html)
        └── static/style.css
```
