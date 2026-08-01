# Mudbase Showcase — Kanban (Go)

A server-rendered Go reimplementation of the reference Next.js team task board (Kanban), built
**entirely on [Mudbase](https://www.mudbase.dev)** — auth, database, and role-based access control
— with **zero custom backend**. This is a sibling port of the reference web app (`../web`) and of
`mudbase-showcase-social/go`, whose framework (net/http + chi + `html/template`, cookie-based
session, the 401 → refresh → retry pattern) this app follows exactly — see `plan/build-plan.md`
"Stack Decisions".

## Stack

Go 1.26 + `net/http` + `chi/v5` + `html/template` + `gorilla/sessions`, talking directly to
`cloud.mudbase.dev` via `github.com/mudbase/mudbase-sdk/go`. Every page is server-rendered; there
is no client-side JavaScript framework and no API route of any kind that isn't Mudbase itself — the
Mudbase JWT lives only in an encrypted, httpOnly session cookie. The only JavaScript in this app is
two small poll-refresh `<script>` blocks (board and activity pages) — this app's stand-in for the
reference web app's Socket.IO realtime subscription, since there is no official Mudbase Go
realtime client.

## What it demonstrates

| Feature | Mudbase capability | Where |
|---|---|---|
| Three-role auth (owner / member / viewer), no anonymous session | `POST /api/auth/local/login`, Multi-Role `customRole` | `internal/mbase/auth.go`, `internal/server/handlers_auth.go` |
| Board columns (lists), owner-managed | Collection CRUD, `lists` | `internal/store/lists.go`, `internal/server/handlers_lists.go` |
| Card CRUD (owner + member) | Collection CRUD, `cards` | `internal/store/cards.go`, `internal/server/handlers_cards.go` |
| Move card between lists / reorder in place | `PATCH` on `listId`/`position` + an `activity` row per move | `internal/store/cards.go` (`MoveToList`, `ReorderInList`) |
| Reverse-chronological activity log | Collection read, `sort: "-createdAt"` | `internal/store/activity.go`, `internal/server/handlers_activity.go` |
| Poll-based "live" board/activity updates | Repeated `GET .../data` on an interval (no official Go realtime client) | `internal/server/handlers_board.go`, `handlers_activity.go` + inline scripts in `board.html`/`activity.html` |
| Role-aware UI, enforced server-side twice | This app's own `requireRole` route middleware + Mudbase's own collection permissions | `internal/rbac`, `internal/server/middleware.go`, verified live below |
| 401 → refresh → retry | `POST /api/auth/refresh`, wired through every collection call via request context | `internal/mbase/refresh.go`, `internal/server/middleware.go` |

## RBAC matrix

| Action | owner | member | viewer |
|---|---|---|---|
| Read lists / cards / activity | Yes | Yes | Yes |
| Create / rename / delete / reorder lists | Yes | No | No |
| Create / edit / delete / move cards | Yes | Yes | No |

This app enforces the matrix **twice, independently**: this app's own route-level middleware
(`requireListManager`/`requireCardManager` in `internal/server/middleware.go`) rejects a
disallowed write before any Mudbase call is made, and Mudbase's own collection permissions
independently reject the exact same write server-side with a `403` regardless — verified live with
a raw `curl` write attempt bypassing this app's routes entirely (see "Live smoke test" below).

## Getting started

```bash
go build ./...
go vet ./...
cp .env.example .env   # fill in SESSION_SECRET (openssl rand -base64 32); collection IDs already
                        # point at the shared demo project
set -a; source .env; set +a
go run ./cmd/server
# → http://localhost:8080
```

Sign in with one of the three demo accounts on the login page (or type credentials manually) — see
`plan/build-plan.md` for account details and the full RBAC verification write-up.

## Provisioning (what already exists on Mudbase, not in this repo)

This app expects a Mudbase project already set up with:

1. Local auth enabled with the Multi-Role feature, three role slugs: `owner`, `member`, `viewer`.
2. Four collections — `boards`, `lists`, `cards`, `activity` — with the field shapes documented in
   `plan/build-plan.md`, and each role granted the permissions in the RBAC matrix above. `boards`
   holds exactly one document, whose id is `MUDBASE_BOARD_ID` (see `.env.example`).

## Live smoke test

See `plan/build-plan.md` → "Live Smoke Test Results" for the full account-by-account,
request-by-request verification against the real project, including a raw `curl` write attempt as
both the `member` and `viewer` roles proving Mudbase's own collection permissions reject them
server-side — not just this app's own middleware or hidden template controls.

## Known limitations (real platform constraints, not bugs)

See `plan/build-plan.md` → "Known Limitations" — no `users` collection (names are denormalized at
write time), same-list reorder uses a simple two-write position swap rather than a
fractional-index scheme (fine at demo scale), and polling instead of a push realtime subscription
(no official Mudbase Go realtime client exists).

## Design choices carried over from the reference web app

- **Button/dropdown card movement, not drag-and-drop** — "move up" / "move down" and a "Move to…"
  select, not a pointer-drag gesture. Keeps this port dependency-light and fully
  keyboard/screen-reader operable.
- **Zero-JS-required editing via `<details>`/`<summary>` popovers** instead of a client-side modal
  dialog — this server-rendered app has no SPA framework to build a modal with. The poll scripts
  explicitly skip replacing the DOM while a `<details open>` popover is on screen, so an
  in-progress edit is never wiped mid-keystroke.

See `plan/build-plan.md` → "Stack Decisions" for the full rationale.

## Environment Variables

See `.env.example`. `SESSION_SECRET` is the only real secret (signs/encrypts the session cookie);
every Mudbase ID is a plain, non-secret identifier.
