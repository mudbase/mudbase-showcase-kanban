# Mudbase Showcase — Kanban (mobile-expo)

A realtime team task board (Kanban) built **entirely on [Mudbase](https://www.mudbase.dev)** —
auth, database, role-based access control, and realtime — with **zero custom backend**. This is
the Expo/React Native port of the reference [`../web`](../web) app: same Mudbase project, same
three collections, same RBAC matrix, same data model. Every other language/platform port in this
showcase is checked against that reference app's data model and API contract.

## Stack

Expo Router (SDK 57) + TypeScript (strict) + NativeWind + TanStack Query + Zustand + Zod +
react-hook-form, talking directly to `cloud.mudbase.dev` via the real generated
[`mudbase-sdk`](https://github.com/mudbase/mudbase-sdk) (`AuthenticationApi` + `DataApi`) — no
hand-rolled REST client, no custom backend of any kind. Every request is made with the signed-in
user's own JWT; there is no server-side code and no privileged credential anywhere in this app.

Architecture mirrors the sibling [`mudbase-showcase-social/mobile-expo`](../../mudbase-showcase-social/mobile-expo)
port: same file layout (`src/api`, `src/config`, `src/lib`, `src/stores`, `src/providers`,
`src/hooks`, `src/components/{ui,auth,board,activity,layout}`), same secure-token pattern, same
Socket.IO wrapper.

## What it demonstrates

| Feature | Mudbase capability | Where |
|---|---|---|
| Three-role auth (owner / member / viewer), **no anonymous/guest session** | `POST /api/auth/local/login` via `AuthenticationApi.loginLocalUser` | `src/api/client.ts`, `src/stores/authStore.ts` |
| Board columns (lists), owner-managed | Collection CRUD, `lists` | `src/hooks/useLists.ts`, `src/components/board/ListColumn.tsx` |
| Card CRUD (owner + member) | Collection CRUD, `cards` | `src/hooks/useCards.ts`, `src/components/board/CardFormModal.tsx` |
| Move card between lists / reorder in place | `PATCH` on `listId`/`position` + an `activity` row per move | `src/hooks/useCards.ts`, `src/components/board/MoveCardPicker.tsx` |
| Reverse-chronological activity log | Collection read, `sort: "-createdAt"` | `src/hooks/useActivity.ts`, `app/(tabs)/activity.tsx` |
| Realtime board + activity | Socket.IO `subscribe:collection` + `db:create`/`db:update`/`db:delete` | `src/hooks/useBoardLive.ts` |
| Role-aware UI, server-enforced | Mudbase's own per-role collection permissions | `src/lib/rbac.ts`, `src/components/layout/AppHeader.tsx` |

## RBAC matrix

| Action | owner | member | viewer |
|---|---|---|---|
| Read lists / cards / activity | Yes | Yes | Yes |
| Create / rename / delete / reorder lists | Yes | No | No |
| Create / edit / delete / move cards | Yes | Yes | No |

The UI hides write controls a role cannot use entirely (never a disabled button with no
explanation) — a viewer sees a small "Read-only — you're signed in as Viewer" banner instead.
Mudbase's own collection permissions are the real enforcement boundary, independently verified
live against this project (see "Live smoke test" below) with raw `fetch` write attempts that never
go through this app's UI at all.

## Card movement: buttons + a "Move to…" picker, not drag-and-drop

Mirrors the web reference's deliberate choice: an up/down icon-button pair reorders a card within
its column, and a "Move to…" modal (the RN equivalent of the web app's `<Select>`) moves it to a
different column, appended to the end. No `react-native-draggable-flatlist`, no extra gesture
wiring beyond what `expo-router`/`react-native-screens` already need — see
`plan/build-plan.md` → "Stack Decisions" for the full rationale.

## Getting started

```bash
npm install
cp .env.example .env   # already points at the shared demo project below; edit if you provision your own
npm run start           # or: npm run ios / npm run android / npm run web
```

Sign in with one of the three demo accounts on the login screen's quick-fill buttons (or type
credentials manually) — see `plan/build-plan.md` for account details and the live RBAC
verification notes.

## Provisioning (already exists on Mudbase, not in this repo)

This app expects a Mudbase project already set up with:

1. Local auth enabled with the Multi-Role feature, three role slugs: `owner`, `member`, `viewer`.
2. Three collections — `lists`, `cards`, `activity` — with the field shapes documented in
   `plan/build-plan.md`, each role granted the permissions in the RBAC matrix above.
3. A `boards` collection with a single document, whose id is this app's `EXPO_PUBLIC_BOARD_ID`
   (must be a real 24-hex-char ObjectId — see `plan/build-plan.md` for why).

`.env.example` lists every id this app needs — all values are `EXPO_PUBLIC_*` since none of them
are secret (every request authenticates with the signed-in user's own JWT, never a static key).

## Live smoke test

See `plan/build-plan.md` → "Live Smoke Test Results" for the full request-by-request verification
against the real project: login for all three roles, list/card CRUD, cross-list move, the
null-vs-empty-string assignee-clear contract, RBAC 403s for member (list-create) and viewer (every
card write) via raw `fetch` bypassing this app's UI entirely, and a live Socket.IO
`subscribe:collection` → `db:create` round-trip confirmed in well under a second.

## Known limitations (real platform constraints, not bugs — carried forward from the web reference)

- **No `users` collection.** Assignee/creator/actor display names are denormalized onto the row
  that references them at write time (`assigneeName`, `createdByName`, `actorName`).
- **Same-list reorder uses a two-write position swap**, not a fractional-index scheme — correct
  and simple at demo scale, would need a fractional/lexicographic key at very large list sizes.
- **`assigneeId`/`boardId` are ObjectId-typed**, not free strings — an assignee's `assigneeId` is
  derived from the typed name via a deterministic hash (`pseudoObjectId()` in `src/lib/format.ts`);
  clearing an assignee sends `null`, never `""` (the platform's query sanitizer rejects the empty
  string as an invalid ObjectId the same way it would reject a made-up slug).
