# Mudbase Showcase — Kanban (web)

A realtime team task board (Kanban) built **entirely on [Mudbase](https://www.mudbase.dev)** —
auth, database, role-based access control, and realtime — with **zero custom backend**. This is
the reference implementation for this showcase: the other 9 language/platform ports (see the repo
root README) are built to match this app's data model and API contract.

## Stack

Next.js 15 (App Router) + TypeScript (strict) + Tailwind + shadcn/ui + TanStack Query, talking
directly to `cloud.mudbase.dev` from the browser. There is no server-side code in this app at
all — no Route Handlers, no server actions that call Mudbase with a privileged credential. Every
request is made with the signed-in user's own JWT.

## What it demonstrates

| Feature | Mudbase capability | Where |
|---|---|---|
| Three-role auth (owner / member / viewer) | Multi-Role signup (`POST /api/auth/local/signup/:role`) | `src/hooks/useAuth.ts`, `src/lib/rbac.ts` |
| No anonymous/guest read — every role signs in | `POST /api/auth/local/login`, `GET /api/auth/session` | `src/lib/mudbase-provider.tsx`, `src/components/auth/AuthGate.tsx` |
| Board columns (lists), owner-managed | Collection CRUD, `lists` | `src/hooks/useLists.ts`, `src/components/board/ListColumn.tsx` |
| Card CRUD (owner + member) | Collection CRUD, `cards` | `src/hooks/useCards.ts`, `src/components/board/CardDialog.tsx` |
| Move card between lists / reorder in place | `PATCH` on `listId`/`position` + an `activity` row per move | `src/hooks/useCards.ts` (`useMoveCardToList`, `useReorderCardInList`) |
| Reverse-chronological activity log | Collection read, `sort: "-createdAt"` | `src/hooks/useActivity.ts`, `src/app/activity/page.tsx` |
| Realtime board + activity | Socket.IO `subscribe:collection` + `db:create`/`db:update`/`db:delete` | `src/hooks/useBoardLive.ts` |
| Role-aware UI, server-enforced | Mudbase's own per-role collection permissions | `src/lib/rbac.ts`, `src/components/layout/Header.tsx` |

## RBAC matrix

| Action | owner | member | viewer |
|---|---|---|---|
| Read lists / cards / activity | ✅ | ✅ | ✅ |
| Create / rename / delete / reorder lists | ✅ | ❌ | ❌ |
| Create / edit / delete / move cards | ✅ | ✅ | ❌ |

The UI hides write controls a role cannot use; Mudbase's own collection permissions are the real
enforcement boundary (verified live — see "Live smoke test" below).

## Getting started

```bash
npm install
cp .env.example .env.local   # already points at the shared demo project; edit if you provision your own
npm run dev
```

Open `http://localhost:3000`. Sign in with one of the three demo accounts on the login page (or
type credentials manually) — see `plan/build-plan.md` for account details and RBAC verification
notes.

## Provisioning (what already exists on Mudbase, not in this repo)

This app expects a Mudbase project already set up with:

1. Local auth enabled with the Multi-Role feature, three role slugs: `owner`, `member`, `viewer`.
2. Three collections — `lists`, `cards`, `activity` — with the field shapes documented in
   `plan/build-plan.md`, and each role granted the permissions in the RBAC matrix above.

`.env.example` lists every ID this app needs once that's done — all values are `NEXT_PUBLIC_*`
since none of them are secret (see `plan/build-plan.md` → "Security Implementation").

## Live smoke test

See `plan/build-plan.md` → "Live smoke test results" for the full account-by-account,
request-by-request verification against the real project, including a raw `fetch` write attempt
as the `viewer` role proving Mudbase's own collection permissions reject it server-side — not
just a hidden UI control.

## Known limitations (real platform constraints, not bugs)

See `plan/build-plan.md` → "Known Limitations" — no `users` collection (names are denormalized at
write time), and same-list reorder uses a simple two-write position swap rather than a
fractional-index scheme (fine at demo scale).

## Design choice: button/dropdown card movement, not drag-and-drop

Cards move via an accessible "move up" / "move down" pair and a "Move to…" list select, not a
pointer-drag gesture (`@dnd-kit/core` or similar). This keeps the reference implementation
dependency-light, fully keyboard/screen-reader operable, and easier for the other 9 ports to
reproduce faithfully. See `plan/build-plan.md` → "Stack Decisions" for the full rationale.
