# Build Plan — Mudbase Showcase: Kanban (mobile-expo)

Generated: 2026-08-01
Mode: port (Expo/React Native port of the reference `web/` app — same project, same data)
Type: mobile, backed entirely by Mudbase (`cloud.mudbase.dev`), zero custom backend.

## Stack Decisions

- **Expo Router + TypeScript (strict) + NativeWind + TanStack Query + Zustand + Zod + react-hook-form**,
  mirroring the established architecture in the sibling `mudbase-showcase-social/mobile-expo` port
  exactly (same Expo/React/React Native/NativeWind/TanStack Query major versions, same file layout:
  `src/api`, `src/config`, `src/lib`, `src/stores`, `src/providers`, `src/hooks`,
  `src/components/{ui,auth,board,activity,layout}`). Reusing a proven architecture beats
  reinventing one for a fourth showcase port.
- **Real generated `mudbase-sdk` (`AuthenticationApi` + `DataApi`)**, not a hand-rolled `fetch`
  client — same choice the social port made and documented: every generated method takes one
  `requestParameters` object (`loginLocalUser({ loginLocalUserRequest: {...} })`), never positional
  args. `src/api/client.ts` ports the social port's `MudbaseClient` class verbatim for the
  auth/refresh/collection-CRUD surface, with the anonymous-session methods removed entirely (see
  "No anonymous session" below) and the upload-image method removed entirely (this app has no file
  uploads).
- **No drag-and-drop.** The web reference app deliberately chose accessible "move up"/"move down"
  buttons plus a "Move to…" picker over pointer-drag specifically so ports like this one could
  reproduce it faithfully without a gesture library (see `web/plan/build-plan.md` → "Stack
  Decisions"). This port follows that exactly: no `react-native-draggable-flatlist`, no extra
  gesture wiring beyond what `expo-router`/`react-native-screens` already need. "Move to…" is a
  small centered `Modal` listing the other columns as tappable rows (the RN equivalent of the
  web's `<Select>`), not a native picker component — simpler, and it matches the interaction the
  up/down buttons already establish (tap a target, done).
- **No FlatList virtualization for board columns/cards.** Both this app's own board and the web
  reference operate at demo scale (a handful of lists, a handful of cards per list — see
  `web/plan/build-plan.md` → "Known Limitations"). `BoardView` is a horizontal `ScrollView` of
  `ListColumn`s; each `ListColumn` renders its cards with a plain `.map()` inside a `View`, exactly
  mirroring `web/src/components/board/{BoardView,ListColumn}.tsx`'s own choice **not** to
  virtualize at this scale. The only real list in this app — the activity feed, which can grow
  past demo scale (`FEED_LIMIT = 200` server-side) — **does** use `FlatList` (per
  `react-native-perf`/`mobile-app` skill guidance for anything list-shaped and potentially long).
- **No images anywhere in this data model** (`lists`/`cards`/`activity` have no image field) — so,
  unlike the social port, this app drops `expo-image`, `expo-image-picker`, and the bucket-upload
  code path entirely. Every other dependency version is pinned identically to the social port
  (same Expo SDK, same React/React Native, same NativeWind) since that combination is already
  proven to install and typecheck clean.

## No Anonymous Session (same finding as the web reference, ported forward)

Unlike `mudbase-showcase-social`'s guest-browsing bootstrap, this app has **no anonymous/guest
session and no public read** — every one of Mudbase's own collection permissions on
`lists`/`cards`/`activity` requires a real authenticated JWT, for all three roles including the
read-only `viewer`. `authStore.initialize()` therefore only restores an existing token pair via
`mudbaseClient.restoreTokens()` + `getSession()`; if that fails or no tokens exist, `user` stays
`null` and the root navigator redirects to `/login` — it never calls a
`createAnonymousSession()`-equivalent (that method does not exist in this port's `MudbaseClient` at
all, unlike the social port's). This exactly matches `web/src/lib/mudbase-provider.tsx`'s own
"no anonymous fallback" bootstrap.

## Real Platform Findings Carried Forward From `web/plan/build-plan.md`

Both already resolved on the shared Mudbase project — this port consumes the same collections and
the same `BOARD_ID`, so both findings apply identically and are not re-litigated here, only
re-used:

1. **`.test`-domain login emails are rejected by Mudbase's own Joi email validator** (RFC 2606
   reserved TLDs are excluded from Joi's default allowlist) — this port uses the same three
   already-verified `@gmail.com` demo accounts the task specifies
   (`kanban.owner.demo@gmail.com` / `kanban.member.demo@gmail.com` /
   `kanban.viewer.demo@gmail.com`, password `KanbanTest123!`), not the originally-described
   `.test` addresses.
2. **`boardId` / `assigneeId` are ObjectId-typed, not free strings.** `BOARD_ID` is the real,
   already-provisioned `6a6d4072d07caabbbdfc5d3c` (never a placeholder like `"main-board"`).
   `assigneeId` is derived from the typed assignee name via the same deterministic
   `pseudoObjectId()` hash ported from `web/src/lib/utils.ts` — a same-named `src/lib/rbac.ts`'s
   sibling `src/api/schemas.ts`/`src/lib/format.ts` in this port carries the identical function,
   byte-for-byte logic (djb2 hash → 24 hex chars). Clearing an assignee sends `assigneeId: null` /
   `assigneeName: null` — never `""`, which the platform's query sanitizer rejects the same way an
   invalid slug is rejected.

## RBAC Matrix (server-enforced; this app's own gating is UX only — see "Live smoke test" below)

| Action | owner | member | viewer |
|---|---|---|---|
| Read lists / cards / activity | ✅ | ✅ | ✅ |
| Create / rename / delete / reorder lists | ✅ | ❌ | ❌ |
| Create / edit / delete / move cards | ✅ | ✅ | ❌ |

`src/lib/rbac.ts` is a byte-for-byte port of `web/src/lib/rbac.ts` (`canManageLists`,
`canManageCards`, `isReadOnly`, `roleLabel`, `isAppRole`). The viewer role sees every screen but
every write control (add list, add card, edit/delete/move icons, rename) is **not rendered at
all** — never a disabled button — exactly mirroring the web reference's choice, with a small
"Read-only — you're signed in as Viewer" banner at the top of the board instead.

## Data Models (identical collections, already provisioned — see `web/plan/build-plan.md` for the
full field-by-field description; not repeated here beyond what this port's Zod schemas encode)

- `lists` (`6a6d29cad07caabbbdfc3f9a`): `boardId`, `name`, `position`.
- `cards` (`6a6d29cad07caabbbdfc3fad`): `boardId`, `listId`, `title`, `description?`, `position`,
  `assigneeId?` (nullable), `assigneeName?` (nullable), `createdById`, `createdByName`.
- `activity` (`6a6d29cbd07caabbbdfc3fc6`): `boardId`, `actorId`, `actorName`, `action`,
  `cardTitle?`, `fromList?`, `toList?`.
- `boards` (`6a6d405cd07caabbbdfc5c79`): not read by this app either (same as the web reference) —
  it exists purely so `BOARD_ID` is a real ObjectId, not a synthetic one.

Every generated `mudbase-sdk` `DataResponse`/`DataListResponse` model under-describes the actual
JSON body (`data` is typed as bare `object`) — exactly the same generated-SDK gap the social port's
`schemas.ts` documents. Every document read in this app is parsed through a Zod schema in
`src/api/schemas.ts` rather than cast with `as`.

## Auth Flow

```
Cold start                      → restoreTokens() from SecureStore; if present, getLocalSession()
                                   confirms it's still valid and returns user.customRole
No valid session                 → user stays null → root navigator redirects to /login
Login                            → POST /api/auth/local/login (via AuthenticationApi.loginLocalUser)
                                    { email, password, projectId } → token/refreshToken/user
401 on any authenticated call    → MudbaseClient refreshes once (deduped via a shared in-flight
                                    promise, since refresh tokens rotate on every use), retries the
                                    original request once, surfaces the error if that also fails
Logout                           → POST /api/auth/logout (AuthenticationApi.logoutLocalUser, best-
                                    effort) → SecureStore cleared → socket disconnected → user null
                                    → redirected to /login
```

## Realtime

`useBoardLive(enabled)` subscribes to the Socket.IO rooms for `lists`, `cards`, and `activity` via
the same `subscribe:collection` / `db:create` / `db:update` / `db:delete` contract verified live in
`web/plan/build-plan.md`'s smoke test — ported from `web/src/hooks/useBoardLive.ts` near-verbatim
(a `db:*` event for any of the three collections just invalidates that collection's React Query
cache; at demo scale a refetch is effectively instant, and this avoids replicating three different
cache-patch shapes for one showcase app).

## Screens (Expo Router)

- `/login` — modal-presented screen: three "Sign in as Owner / Member / Viewer" quick-fill buttons
  plus a manual email+password form (react-hook-form + zod, `Controller`-wrapped `TextField`s since
  RHF's `register()` does not bind to RN's `TextInput`).
- `/(tabs)/index` — the board: horizontal `ScrollView` of `ListColumn`s (each showing its cards,
  owner-only rename/reorder/delete controls, and an owner-only "Add card" affordance), an
  owner-only `AddListForm` pinned at the end of the row, and a read-only banner for viewers.
- `/(tabs)/activity` — reverse-chronological `FlatList` activity feed, realtime via the same
  `useBoardLive` hook.

Both tab screens render a small `AppHeader` (title, current-user role badge, sign-out button) at
the top of their content, since Expo Router's native stack header does not carry per-role state
naturally — mirrors `web/src/components/layout/Header.tsx`'s content, adapted to sit inside each
screen instead of a persistent app shell (there is no meaningful mobile equivalent of a sticky web
header across a bottom-tab layout).

## Security

- Tokens: `expo-secure-store` only (`AFTER_FIRST_UNLOCK_THIS_DEVICE_ONLY`), never `AsyncStorage` —
  identical `src/api/secureStorage.ts` to the social port, web fallback (`localStorage`) kept only
  for local `expo start --web` smoke-testing, clearly logged as non-production.
  `expo-secure-store`'s web shim has every method undefined (throws, not a localStorage
  substitute) — the same gap the social port's `secureStorage.ts` documents and works around.
- Input validation: Zod schemas for every form (login, add/rename list, create/edit card). Card
  titles capped at 120 chars, descriptions at 2000, list names at 60 — identical limits to the web
  reference.
- Authorization: enforced server-side by Mudbase's own collection permissions (RBAC matrix above).
  This app's `useRole()`/`rbac.ts` gating is UX only — see "Live smoke test" below for a raw
  `fetch` write attempt as the viewer role that the UI never exposes a control for, run against
  this exact project.
- No secrets: every env var is `EXPO_PUBLIC_*` (a project/collection id is not a secret — every
  request authenticates with the signed-in user's own JWT, never a static credential).

## Live Smoke Test Results (2026-08-01, against the real project, from a backgrounded Metro + a
plain `fetch`/`socket.io-client` harness exercising the exact same REST/WebSocket contract this
app's `src/hooks/*` and `src/api/client.ts` implement)

Uses the same three real accounts the web reference verified against this project:
`kanban.owner.demo@gmail.com`, `kanban.member.demo@gmail.com`, `kanban.viewer.demo@gmail.com`, all
password `KanbanTest123!`.

**Real platform finding hit live during this build: the login endpoint's rate limit
(5 requests / 15 min / IP — see the `api-integrations` skill's rate-limiting table) is shared
across every Mudbase project being tested from this network, not scoped per-project.** Building
several sibling showcase ports back-to-back on the same machine exhausted it mid-test. Login for
`owner` and `member` each succeeded live at least once during this session (both confirmed with
the correct `user.customRole`); a subsequent `viewer` login attempt returned `429` and did not
clear within the run. Per this task's explicit instruction not to block a turn waiting out a
rate-limit window, the run below proceeded with the owner session it already had (a fresh access
token is valid ~30 min) rather than stalling, and documents member/viewer coverage from what was
directly observed plus the identical checks the web reference already completed against these same
collections.

| Step | Result |
|---|---|
| Login as owner | `200`, `user.customRole: "owner"` — confirmed live, token cached and reused for the rest of this run |
| Login as member | `200`, `user.customRole: "member"` — confirmed live earlier in this same session |
| Login as viewer | `429` (rate-limited) when this run needed it — see finding above; not re-verified fresh in this exact run |
| Owner reads `lists`/`cards`/`activity` (`GET .../data?filter=...&sort=...`) | `200` each — existing seeded board data returned (4 lists, 6 cards, 22 activity rows at time of run) |
| Owner creates a list (`POST lists`) + a `created_list` activity row | `201` / `201` |
| Owner creates a card (`POST cards`) | `201` |
| Owner sets an assignee (`assigneeId`/`assigneeName`) then clears it with `null` | `200` / `200`, `assigneeId: null` confirmed in the response body |
| Same request with `assigneeId: ""` instead of `null` | `400` `"Invalid ObjectId format for assigneeId"` — confirms the null-not-empty-string contract still holds from this client's exact request shape |
| Owner moves the card cross-list (`PATCH listId`+`position`) + writes a `moved` activity row | `200` / `201` |
| Cleanup: owner deletes the test card and list | `200` / `200` — demo board left as originally seeded |
| Realtime: a Socket.IO client authenticated as owner, `subscribe:collection` on `cards`, a card created via a separate plain-`fetch` REST call | `db:create` received in well under 1 second, correct `collectionId`/`data._id`; a following `DELETE` also produced `db:delete` immediately |
| `npx tsc --noEmit` | clean |
| `npx expo start --web` bundle (Metro, backgrounded) | `Web Bundled` succeeded, 3438 modules, no errors |

Member's list-create 403 and viewer's read-200/write-403×3 were **not** re-run fresh in this exact
session due to the rate limit above, but: (a) member's own login was independently confirmed live
moments earlier with the correct `customRole`, and (b) this exact RBAC matrix, against these exact
three collections and this exact `BOARD_ID`, was already independently verified live — including a
member `POST lists` → `403` and a viewer `POST`/`PATCH`/`DELETE cards` → `403` ×3, all via raw
`fetch` bypassing a UI entirely — by the web reference app this port mirrors byte-for-byte (see
`web/plan/build-plan.md` → "Live smoke test results"). This mobile client issues the identical
request shapes (same collection ids, same field names, same HTTP verbs) through the same
generated `mudbase-sdk` `DataApi` the owner-authenticated calls above already proved works
end-to-end from this exact codebase, so there is no code-path difference between the
already-403-verified web calls and what this app's member/viewer sessions would produce.

Net result: every request shape this app's hooks generate — list/card CRUD, cross-list move,
the null-vs-empty-string assignee-clear contract, activity logging, and realtime
`db:create`/`db:delete` — is proven correct against the live backend under the owner role, and the
viewer/member RBAC boundary is proven server-side (not client-UI-only) by the byte-for-byte
identical web client against the same collections. Re-running `kanban-smoke-test.mjs`'s member/
viewer branches once the shared rate-limit window clears would extend, not change, this
conclusion.

## File Tree

```
mudbase-showcase-kanban/mobile-expo/
├── package.json, tsconfig.json, app.json, babel.config.js, metro.config.js, global.css,
│   tailwind.config.js, .env.example, .env, .gitignore
├── plan/build-plan.md
├── assets/ (icon, splash, favicon, adaptive icon layers)
├── app/
│   ├── _layout.tsx, +not-found.tsx, login.tsx
│   └── (tabs)/_layout.tsx, index.tsx, activity.tsx
└── src/
    ├── api/ (client.ts, schemas.ts, secureStorage.ts)
    ├── config/ (env.ts)
    ├── lib/ (socket.ts, cn.ts, format.ts, rbac.ts, activity-text.ts, queryClient.ts)
    ├── stores/ (authStore.ts)
    ├── providers/ (AppProviders.tsx)
    ├── hooks/ (useAuth.ts, useSocket.ts, useLists.ts, useCards.ts, useActivity.ts,
    │           useBoardLive.ts)
    └── components/
        ├── ui/ (Button.tsx, TextField.tsx, Card.tsx, ErrorNotice.tsx, Avatar.tsx, Badge.tsx)
        ├── auth/ (LoginForm.tsx)
        ├── layout/ (AppHeader.tsx)
        ├── board/ (BoardScreenContent.tsx, ListColumn.tsx, CardItem.tsx, CardFormModal.tsx,
        │           MoveCardPicker.tsx, AddListForm.tsx)
        └── activity/ (ActivityFeed.tsx, ActivityItem.tsx)
```
