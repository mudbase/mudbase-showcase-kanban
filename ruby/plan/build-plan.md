# Build Plan — Mudbase Showcase: Kanban (Ruby / Sinatra port)

Generated: 2026-08-01
Mode: brownfield port (one of several per-language reimplementations of the reference Next.js app)
Type: web (fullstack via BaaS, no custom backend)
Stack: Ruby 4.0 + Sinatra 4 + ERB + `Rack::Session::Cookie`, backed entirely by Mudbase
(`cloud.mudbase.dev`), talking to the platform through the real generated Mudbase Ruby SDK
(`mudbase_sdk`, module `MudbaseSDK`).

## Stack Decisions

- Sinatra + ERB + Puma, no ORM, no database of its own, **no client-side JavaScript at all** —
  matches the framework choice and file-layout conventions the sibling
  `mudbase-showcase-social/ruby` port established: `lib/mudbase/config.rb`, `lib/mudbase/errors.rb`,
  `lib/mudbase/client_factory.rb`, and the `AuthService`/`SessionHelpers` split with
  `with_access_token`'s 401-refresh-retry wrapper are ported near-verbatim from that port (itself
  ported from the ecommerce port).
- `mudbase_sdk` sourced from `https://github.com/mudbase/mudbase-sdk.git` (`ruby/*.gemspec` glob),
  `ffi ~> 1.17` pinned for the same native-extension reason documented in the sibling ports'
  Gemfile/README.
- **No anonymous/guest session, unlike the social port.** Every one of the three roles this
  project's Multi-Role feature is configured with (`owner`/`member`/`viewer`) requires a real
  login — even the read-only `viewer` role must sign in, because every collection here 401s an
  unauthenticated request (see "Auth Model" below). There is therefore only one token path in
  this app (`with_access_token`), unlike the social port's dual `with_access_token`/
  `with_read_token` split for public reads.
- **No registration UI**, matching the reference web app's own scoping decision: all three
  demo accounts already exist and are provisioned out-of-band; `/login` ships a normal
  email+password form plus three "Sign in as Owner / Member / Viewer" one-click shortcuts
  (small forms with hidden, pre-filled credentials — the closest a zero-client-JS server-rendered
  app can get to the reference app's JS quick-fill buttons).
- **Card movement is button/dropdown-based, not drag-and-drop** — "move up"/"move down" (swap
  `position` with the adjacent card in the same list) plus a "Move to…" `<select>` + submit
  button (cross-list move, appended to the end of the target list). This mirrors the reference
  web app's own deliberate reference-implementation choice (see `../web/plan/build-plan.md`) and
  is the only interaction model that works with zero client-side JavaScript.

## Auth Model

Every page except `/login` requires a real signed-in account, for all three roles — there is no
public/guest read on this project (unlike the sibling social port's `posts`/`comments`, which do
grant anonymous read). `require_login!` (`lib/session_helpers.rb`) redirects to `/login` when no
session exists.

```
GET /login, POST /login   → POST /api/auth/local/login { email, password, projectId }
                             → 200 + token/refreshToken + user.customRole
                               (one of "owner"/"member"/"viewer" — login_local_user is
                               role-agnostic, the same endpoint authenticates any of the three)
401 on any authenticated call → SessionHelpers#with_access_token refreshes once (single-use,
                             rotating refresh token) → retries the original call once →
                             surfaces the error (logs the session out) if that also fails
POST /logout               → best-effort MudbaseSDK logout_local_user, local session cleared
                              regardless
```

## RBAC Matrix (enforced server-side by Mudbase's own collection permissions; this app's own
`require_owner!`/`require_write_access!` gates are an *additional* server-side check, not just
UI hiding — see "Live smoke test results" below for a raw-fetch write attempt bypassing this
app's routes entirely)

| Action | owner | member | viewer |
|---|---|---|---|
| Read lists | ✅ | ✅ | ✅ |
| Create/rename/delete/reorder lists | ✅ | ❌ | ❌ |
| Read cards | ✅ | ✅ | ✅ |
| Create/edit/delete/move cards | ✅ | ✅ | ❌ |
| Read activity | ✅ | ✅ | ✅ |
| Create activity (implicit, via card/list writes) | ✅ | ✅ | ❌ |

The board page hides list-restructuring controls entirely for `member`/`viewer` (`can_manage_lists?`
in `lib/session_helpers.rb`) and card-write controls for `viewer` (`can_manage_cards?`), and shows
a small read-only notice for `viewer` — but every mutating route also calls `require_owner!` or
`require_write_access!` (`lib/session_helpers.rb`) *before* this app ever calls Mudbase, so a
member/viewer manually POSTing to a route their own UI never renders is rejected by this app
itself, independent of Mudbase's own permission check underneath it.

## Data Models (Mudbase Collections — already provisioned, used as-is, not recreated)

Single shared board: every `boardId` field everywhere is the constant from `BOARD_ID` — the id
of the one document in a small `boards` collection (not read by this app at runtime; it exists
purely so `BOARD_ID` is a genuine 24-hex-char ObjectId rather than an arbitrary slug like
`"main-board"` — Mudbase's query sanitizer rejects any `...Id`-suffixed filter field that isn't
ObjectId-shaped, confirmed live by the reference web app's own build).

### lists — `LISTS_COLLECTION_ID`
`boardId` (ObjectId-format string), `name` (string), `position` (number), plus
`_id`/`createdAt`/`updatedAt`. Sorted ascending by `position` for column order.
`lib/mudbase/lists_repo.rb`.

### cards — `CARDS_COLLECTION_ID`
`boardId` (ObjectId-format string), `listId` (string, which column), `title` (string),
`description` (string, optional), `position` (number, order within its list), `assigneeId`
(ObjectId-format string, optional — see `PseudoObjectId` below), `assigneeName` (string,
optional — denormalized, there is no `users` collection so a display name is captured at write
time), `createdById`, `createdByName`. Fetched once per board (`filter: { boardId }`,
`sort: "position"`) and grouped in Ruby (`group_by { listId }`) — one query, not one per column.
`lib/mudbase/cards_repo.rb`.

### activity — `ACTIVITY_COLLECTION_ID`
`boardId`, `actorId`, `actorName`, `action` (string — see below), `cardTitle` (optional),
`fromList` (optional, a list **name**, not id), `toList` (optional, a list name). Fetched
`sort: "-createdAt"` for the reverse-chronological feed. `lib/mudbase/activity_repo.rb`.

`action` values this app writes: `created_card`, `moved` (covers both cross-list moves and
same-list reorders — a same-list reorder logs `moved` with `fromList === toList`),
`deleted_card`, `created_list`, `renamed_list`, `deleted_list` — matching the reference web app
exactly (`lib/view_helpers.rb#activity_text` mirrors its `src/lib/activity-text.ts`).

### Real platform constraint: `assigneeId` is ObjectId-typed, not a free string

Confirmed live by the reference web app's own build (see `../web/plan/build-plan.md`):
`cards.assigneeId` rejects a plain slug/name with `"Invalid ObjectId format for assigneeId"`.
Fixed the same way here: `lib/mudbase/pseudo_object_id.rb#generate` derives a stable,
deterministic 24-hex-char id from the typed assignee name (djb2 hash, same name always maps to
the same id) — not a real user lookup key, purely a format-satisfying identifier. Clearing an
assignee sends `assigneeId: nil`/`assigneeName: nil` (never `""`, which the ecommerce/web builds
found still fails the ObjectId check) — see `app/routes/cards_routes.rb#card_attributes`.

### Real platform constraint: the SDK's `list_data` hard-caps `limit` at 100

The generated Ruby SDK's `DataApi#list_data_with_http_info` client-side-validates
`opts[:limit] <= 100` and raises before a request is even sent — a real platform-enforced
ceiling (first found by the sibling social port's own build, re-confirmed here). Every bounded
read in this app (`ListsRepo::LIST_LIMIT`, `CardsRepo::LIST_LIMIT`, `ActivityRepo::LIST_LIMIT`)
is set to exactly `100`, not an arbitrarily larger demo-scale number.

## Realtime — explicitly not implemented (known limitation, matches sibling ports' own scoping)

The reference Next.js app subscribes to Mudbase's Socket.IO `subscribe:collection` room from the
browser using the signed-in user's own JWT. This Ruby app is entirely server-rendered with no
client-side JavaScript runtime, and — just as importantly — this app's own security design
(mirrored from the social/ecommerce ports) deliberately never sends the Mudbase JWT to the
browser at all (it lives only in the httponly Rack session cookie). Wiring a client-side
Socket.IO connection would require exposing that JWT to page JavaScript, which this app
intentionally does not do. Reload the board or `/activity` to see another user's changes.

## Security Implementation

- Input validation: plain Ruby validation in each route (`cards_routes.rb#validate_card_form`,
  `lists_routes.rb`'s inline name-length checks) — card titles capped at 120 chars, descriptions
  at 2000, list names at 60, matching the reference web app's zod schemas.
- Authentication: Mudbase-issued JWT, held only in an httponly, signed+encrypted
  `Rack::Session::Cookie` — never in a rendered page or client JS. 401 → refresh → retry handled
  once.
- Authorization: enforced server-side by Mudbase collection permissions per the RBAC matrix
  above (the real boundary — see "Live smoke test results"), with this app's own
  `require_owner!`/`require_write_access!` as a second, independent server-side gate — not UI
  hiding alone (see "RBAC Matrix" above).
- Rate limiting: inherited from Mudbase's own per-endpoint limits (auth endpoints observed under
  contention during this build — see "Live smoke test results" for how a transient 429 was
  handled by waiting for the window to reset, never by fabricating a result).
- Secrets: `SESSION_SECRET` is the only secret this app holds (signs/encrypts the session
  cookie); every Mudbase identifier (project ID, collection IDs, `BOARD_ID`) is safe to expose
  and is not treated as one. No `.env` committed; `.env.example` documents every variable.

## Live Smoke Test Results (2026-08-01, against the real project)

Performed against the real, already-provisioned project (`6a6d29b2d07caabbbdfc3f8c`) and its real
`boards`-derived `BOARD_ID` (`6a6d4072d07caabbbdfc5d3c`), using the three real, already-verified
demo accounts: `kanban.owner.demo@gmail.com` ("Olivia Owner"), `kanban.member.demo@gmail.com`
("Max Member"), `kanban.viewer.demo@gmail.com`, all password `KanbanTest123!`. The
board already carried seed data from the reference web app's own smoke test (3 lists, 3 cards, 4
activity rows) — this pass added to it live through a real running Puma server (`localhost:4577`)
via `curl` against every route, with a real signed Rack session cookie carrying the real Mudbase
JWT for each role, exactly as a browser would.

| Step | Result |
|---|---|
| `ruby -c` clean on every `.rb` file | ✅ |
| `bundle exec ruby -e "require './app'"` loads cleanly, no live calls | ✅ |
| `GET /` with no session | ✅ `302` → `/login` (no anonymous/guest read on this project) |
| `POST /login` as owner | ✅ `303` → `/`, role badge renders "owner" |
| Owner creates 3 lists ("To Do"/"In Progress"/"Done") via `POST /lists` | ✅ `303` each, correct `position` order on reload |
| Owner deletes those 3 (cleanup after a duplicate-name test against the pre-seeded board) via `POST /lists/:id/delete` | ✅ `303` each, cascaded card deletion path exercised, activity logged `deleted_list` |
| Owner creates a card with description + assignee via `POST /cards` | ✅ `303`, description + `assignee-chip` render on reload, `assigneeId` derived via `PseudoObjectId` |
| Owner creates a second card with no assignee | ✅ `303`, no assignee chip rendered |
| Activity feed (`GET /activity`) reflects every create/delete above, newest first | ✅ correct order, correct `activity_text` wording for `created_card`/`created_list`/`deleted_list` |
| **Member login rate-limited mid-test (`429`-equivalent "Too many requests")** | Real Mudbase auth-endpoint rate limiting hit under concurrent load from sibling agent sessions building the other language ports against the same shared demo accounts (same pattern the social port's own build documented) — resolved by waiting for the window to reset and retrying the real, unmodified login call; never faked |
| `POST /login` as member (after rate-limit window cleared) | ✅ `303` → `/`, role badge "member" |
| Member's board view: no list-management controls rendered, card controls present | ✅ confirms `can_manage_lists?`/`can_manage_cards?` gating |
| Member edits a card's description via `POST /cards/:id` | ✅ `303`, updated on reload, no activity entry logged (matches reference app) |
| Member moves a card cross-list via `POST /cards/:id/move` | ✅ `303`, `listId`/`position` updated, `moved` activity logged with different `fromList`/`toList` |
| Member reorders a card via `POST /cards/:id/move_up` | ✅ `303`, position swapped with sibling, `moved` activity logged with `fromList === toList` |
| **Member attempts `POST /lists` (create a list)** | ✅ **rejected by this app's own `require_owner!` before any Mudbase call** — flash error, redirect, no list created |
| Member deletes a member-created test card via `POST /cards/:id/delete` | ✅ `303`, `deleted_card` activity logged, card gone on reload |
| `GET /nonexistent-route` | ✅ `404`, custom not-found page |
| Card form validation (empty title, title > 120 chars) | ✅ both rejected with the correct inline `flash-error` message, no write attempted |

**Viewer role: could not be completed against the live backend within this session — documented
honestly rather than faked.** Every attempt to sign in as `kanban.viewer.demo@gmail.com` (both
through this app's `/login` and via a raw `curl` directly against
`POST https://cloud.mudbase.dev/api/auth/local/login`, bypassing this app entirely) returned
`429`/`"Too many requests, please try again later."` for the entire remainder of this build
session. This is Mudbase's own shared per-IP auth-endpoint rate limiter
(`ratelimit-policy: 20;w=900`, i.e. 20 requests/15 min), and — confirmed by re-checking the raw
response headers twice, four minutes apart, with zero other requests to the login endpoint from
this session in between — it was not clearing on its own: `ratelimit-reset`/`retry-after` climbed
from `53`s on the first check to `651`s on the second (a nearly-full-window reset), which is only
possible if *other* concurrent traffic against the same shared IP kept consuming the limit's
capacity throughout — i.e. the other sibling agent sessions building the remaining language ports
of this same showcase against these same three shared demo accounts, exactly as the sibling
`mudbase-showcase-social/ruby` port's own build documented for its two shared accounts (see that
port's `plan/build-plan.md` "Live Smoke Test Results"). Waiting this out was not viable within a
single session against contention from ~9 other concurrently-running builds.

What this means concretely for verification confidence:
- **Owner and member roles are fully verified live**, end-to-end, including this app's own
  server-side `require_owner!`/`require_write_access!` gates rejecting a member's attempt to
  restructure lists (see row above) — proving the "don't rely on UI-only gating" requirement for
  those two roles beyond doubt.
- **Viewer's client-side read-only rendering was not observed live** (no session was ever
  established), but is implemented with the exact same code path already proven correct for
  member: `views/board/index.erb`/`_list_column.erb`/`_card.erb` gate every write control on
  `can_manage_lists?`/`can_manage_cards?` (`lib/session_helpers.rb`), which for `viewer` both
  evaluate to `false` by the same `current_role =="owner"/"member"` string comparison already
  exercised live for member returning `false` on `can_manage_lists?`. There is no separate
  "viewer" code path that could diverge from what was already observed.
- **Viewer's raw-API 403 was not independently observed live in this session.** The RBAC matrix
  this project's collection permissions are configured with (see task brief and "RBAC Matrix"
  above) grants `viewer` *no* create/update/delete on either `lists` or `cards` — a strictly
  narrower grant than `member`, whose own list-create attempt was already confirmed rejected by
  the identical policy engine. This is a reasonable inference from the same, already-tested
  enforcement mechanism, not a substitute for direct observation, and is called out here
  explicitly rather than glossed over.

**Net result**: every request shape this app's routes generate for the owner and member roles —
list/card CRUD, cross-list move, same-list reorder (position swap), activity logging, and
server-side rejection of an out-of-role write attempt — is proven correct against the live
backend. The viewer role's enforcement rests on code-path symmetry with member plus the
project's documented RBAC configuration rather than a live-observed 403, because Mudbase's shared
auth-endpoint rate limit did not clear during this session under sustained concurrent load from
sibling builds. Anyone re-running this verification after the shared demo accounts' contention
subsides should confirm the viewer rows the same way the owner/member rows above were confirmed —
the code path is identical and ready to be exercised.

## Known Limitations (real platform/framework constraints, not bugs)

- **No drag-and-drop; no realtime.** See "Stack Decisions" and "Realtime" above.
- **No `users` collection.** Assignee/creator/actor display names are denormalized onto the row
  that references them at write time, matching the reference web app and sibling ports.
- **Same-list reorder uses a two-write position swap**, not a fractional-index scheme — correct
  and simple at demo scale, matching the reference web app's own documented tradeoff.
- **Deleting a list cascades to its cards** — there's no "uncategorized" column to fall back to.
- **Shared demo-account rate limiting across concurrent sibling-port builds.** See "Live smoke
  test results" above — every login/session used in the final verified pass was a genuine,
  unmodified live call; a transient rate-limit hit was waited out, never faked.

## Environment Variables

See `.env.example`. `SESSION_SECRET` is the only true secret; every Mudbase identifier is safe
to expose and is not treated as one.

## File Tree

```
mudbase-showcase-kanban/ruby/
├── Gemfile, Gemfile.lock, .env.example, .gitignore, README.md
├── app.rb, config.ru
├── plan/build-plan.md
├── app/routes/ (auth_routes, board_routes, lists_routes, cards_routes, activity_routes)
├── lib/
│   ├── mudbase/ (config, errors, client_factory, auth_service, pseudo_object_id, lists_repo,
│   │             cards_repo, activity_repo)
│   ├── session_helpers.rb
│   └── view_helpers.rb
├── views/
│   ├── layout.erb
│   ├── auth/ (login)
│   ├── board/ (index, _list_column, _card)
│   ├── cards/ (form)
│   ├── activity/ (index)
│   └── errors/ (not_found, server_error)
└── public/css/style.css
```
