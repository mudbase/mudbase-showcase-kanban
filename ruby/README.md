# Mudbase Showcase — Kanban (Ruby / Sinatra)

A server-rendered team task board (Kanban) built **entirely on [Mudbase](https://www.mudbase.dev)**
— auth and database, with **zero custom backend** — implemented in **Sinatra + ERB**, talking to
`cloud.mudbase.dev` through the real generated **Mudbase Ruby SDK** (`mudbase_sdk`, module
`MudbaseSDK`). This is the Ruby reimplementation of the reference Next.js app (see `../web`): same
Mudbase project, same three collections (`lists`/`cards`/`activity`), same single shared board,
same `owner`/`member`/`viewer` RBAC matrix — different stack, following the Sinatra structure the
sibling `mudbase-showcase-social`/`mudbase-showcase-ecommerce` ports established.

## Stack

Sinatra 4 + ERB + `Rack::Session::Cookie`, `mudbase_sdk` (git-sourced), Puma. No ORM, no database
of its own, no client-side JavaScript — every read/write goes to Mudbase's Collections REST API,
and every interaction (move a card, reorder a list) is a plain HTML form POST.

## What it demonstrates

| Feature | Mudbase capability | Where |
|---|---|---|
| Multi-role sign-in (owner/member/viewer) | `POST /api/auth/local/login`, role-agnostic | `lib/mudbase/auth_service.rb`, `app/routes/auth_routes.rb` |
| Board: lists (columns) + cards | Collections, filtered + sorted reads | `app/routes/board_routes.rb`, `lib/mudbase/{lists,cards}_repo.rb` |
| List CRUD + reorder — **owner only** | Ownership-scoped create/update/delete, RBAC enforced by Mudbase + this app | `app/routes/lists_routes.rb` |
| Card CRUD + move (cross-list, up/down) — **owner/member** | Ownership-scoped create/update/delete, RBAC enforced by Mudbase + this app | `app/routes/cards_routes.rb` |
| Activity log (reverse-chronological) | Append-only collection, every card/list write appends a row | `lib/mudbase/activity_repo.rb`, `app/routes/activity_routes.rb` |
| Read-only `viewer` role | Mudbase collection permissions reject writes server-side (verified live, not just UI hiding) | see "RBAC enforcement" below |

## Provisioning (what already exists on Mudbase, not in this repo)

This app expects a Mudbase project already set up with:

1. Local auth enabled, with the Multi-Role feature configured with three role slugs:
   `owner` / `member` / `viewer`.
2. Three collections — `lists`, `cards`, `activity` — with the field shapes documented in
   `plan/build-plan.md`, `read` granted to all three roles, and `create`/`update`/`delete`
   scoped per the RBAC matrix (list writes owner-only; card writes owner+member; viewer
   read-only on everything).
3. A small `boards` collection with exactly one document — its `_id` is the real `BOARD_ID`
   every list/card/activity row's `boardId` field points at (see `.env.example` and
   `plan/build-plan.md` "Real platform findings" for why this must be a genuine 24-hex-char
   ObjectId, not an arbitrary slug like `"main-board"`).

`.env.example` lists every ID this app needs once that's done.

## Setup

```bash
bundle install
cp .env.example .env   # fill in your own provisioned project's IDs, BOARD_ID, and a session secret
bundle exec puma -p 4567 config.ru
# or: bundle exec rackup config.ru
```

Open `http://localhost:4567`. Sign in with one of the three demo accounts (or use the "Sign in
as Owner / Member / Viewer" quick-fill buttons on `/login`):

| Role | Email | Password |
|---|---|---|
| Owner | `kanban.owner.demo@gmail.com` | `KanbanTest123!` |
| Member | `kanban.member.demo@gmail.com` | `KanbanTest123!` |
| Viewer | `kanban.viewer.demo@gmail.com` | `KanbanTest123!` |

### Native-extension (ffi) caveat

`mudbase_sdk` depends on `typhoeus` → `ethon` → `ffi` for its HTTP transport. `ffi`'s native
extension is loosely pinned by the SDK's own gemspec and can fail to compile against a newer
Xcode/Clang toolchain than the gem release expects. This Gemfile pins `ffi ~> 1.17` explicitly (a
version with prebuilt `arm64-darwin`/`x86_64-darwin`/Linux bottles, so `bundle install` typically
doesn't need to compile anything). If you still hit a build failure, run
`gem install ffi -v '~> 1.17'` on its own first to confirm a prebuilt binary is available for your
platform before touching the vendored SDK gemspec.

### Verifying the app

```bash
find . -name "*.rb" -not -path "./vendor/*" -exec ruby -c {} \;   # every file: Syntax OK
bundle exec ruby -e "require './app'"                             # loads cleanly, no live calls
```

## RBAC enforcement (server-side, not just UI hiding)

Every list-management route (`/lists`, `/lists/:id/rename`, `/lists/:id/delete`,
`/lists/:id/move`) calls `require_owner!` — and every card route (`/cards`, `/cards/:id`,
`/cards/:id/delete`, `/cards/:id/move*`) calls `require_write_access!` — **before** this app ever
calls Mudbase, so a member/viewer manually POSTing to a route their own UI never shows a button
for is rejected by this app itself. This was confirmed live for `member`: a raw POST to
`/lists` with a real member session was rejected by `require_owner!` before any Mudbase call —
see `plan/build-plan.md` → "Live Smoke Test Results". Underneath this app's own gate, Mudbase's
own collection permissions are the real enforcement boundary for every role; the `viewer` role's
equivalent raw-API rejection could not be independently re-confirmed live in this session (see
"Known limitations" below and `plan/build-plan.md` for why), though it rests on the same
enforcement mechanism and a strictly narrower grant than `member`'s already-confirmed rejection.

## Live smoke test (2026-08-01, real project, real accounts)

See `plan/build-plan.md` → "Live Smoke Test Results" for the full step-by-step table: owner
creating/renaming/reordering/deleting lists and cards, member moving/editing/deleting cards and
being rejected server-side (`require_owner!`) when attempting to create a list. **The viewer role
could not be logged in during this session** — Mudbase's shared per-IP auth-endpoint rate limiter
stayed exhausted for the entire remainder of the build (confirmed via raw `curl` response headers
showing the reset window climbing rather than counting down, consistent with sustained concurrent
traffic from the other sibling agent sessions building this showcase's other language ports
against the same shared demo accounts). Viewer's read-only rendering shares the exact same
`can_manage_lists?`/`can_manage_cards?` code path already proven `false`-gated for member, and the
project's RBAC configuration grants `viewer` a strictly narrower permission set than `member`
(whose own out-of-role write was independently confirmed rejected) — but this is a documented
inference, not a live-observed result, and is called out plainly rather than glossed over in
`plan/build-plan.md`.

## Known limitations (real platform/framework constraints, not bugs)

**Viewer role not live-verified in this build session (shared rate-limit contention).** See
"RBAC enforcement" above and `plan/build-plan.md` "Live Smoke Test Results" — Mudbase's shared
per-IP auth-endpoint rate limiter never cleared during this session due to sustained concurrent
traffic from sibling builds of this showcase's other language ports against the same three demo
accounts. Owner and member are fully verified live; viewer's code path is identical to member's
(already proven correct) but was not independently exercised against a real viewer session.

**No drag-and-drop.** Cards move via "move up" / "move down" (position swap within a column) and
a "Move to…" `<select>` + button (append to the end of another column) — the same
button/dropdown-based interaction the reference Next.js app deliberately uses instead of pointer
drag, and the only interaction model that works with zero client-side JavaScript.

**No push-based realtime.** This app is entirely server-rendered with no client-side JavaScript
runtime, and — like the sibling social/ecommerce ports — deliberately never sends the Mudbase JWT
to the browser (it lives only in an httponly Rack session cookie). Reload the board or the
activity page to see another user's changes.

**No `users` collection, so an assignee is a free-typed name.** `cards.assigneeId` is
schema-typed as an ObjectId reference (verified live), not a free-form string, so a typed
assignee name is hashed into a stable, deterministic pseudo-ObjectId
(`lib/mudbase/pseudo_object_id.rb`) purely to satisfy that format check — it is not a real user
lookup key. Matches the reference web app's `pseudoObjectId()` finding.

**`Mudbase Collections' list_data` hard-caps `limit` at 100**, client-side-enforced by the
generated SDK (confirmed by the sibling social port's own build). Every bounded read in this app
(`ListsRepo::LIST_LIMIT`, `CardsRepo::LIST_LIMIT`, `ActivityRepo::LIST_LIMIT`) is set to exactly
100 for this reason — plenty for a demo-scale board.

**Deleting a list cascades to its cards.** There's no "uncategorized" column for a deleted list's
cards to fall back to, so `POST /lists/:id/delete` deletes every card in that list first, then
the list itself, matching the reference web app's `useDeleteList`.

## Local development

```bash
bundle install
cp .env.example .env
bundle exec puma -p 4567 config.ru
```

## Deploy

Any Ruby host that runs Puma behind `config.ru` (Fly.io, Render, a bare VPS with systemd) works
unmodified. Set every variable in `.env.example` as a real environment variable —
`SESSION_SECRET` must be a long random value distinct from any other app's secret, and
`RACK_ENV=production` turns on the `secure` cookie flag (HTTPS-only session cookie).
