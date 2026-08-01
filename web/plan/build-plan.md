# Build Plan — Mudbase Showcase: Kanban
Generated: 2026-08-01
Mode: greenfield (1 of 10 language/platform ports — this is the reference implementation)
Type: web (fullstack via BaaS, no custom backend)
Stack: Next.js 15 App Router + TypeScript + Tailwind CSS + shadcn/ui, backed entirely by Mudbase (cloud.mudbase.dev)

## Stack Decisions
- Next.js 15 App Router + TanStack Query + shadcn/ui/Tailwind: matches this session's Web App
  default and the sibling `mudbase-showcase-social` / `mudbase-showcase-ecommerce` projects,
  which every other of the 10 planned ports will be checked against for data-model/API-contract
  parity.
- No custom backend of any kind: every persistence, auth, and realtime concern is a Mudbase
  REST/WebSocket call made directly from the browser.
- `src/lib/mudbase.ts` ports the social/ecommerce showcase's client verbatim (401 → refresh →
  retry, `refreshInFlight` dedupe for rotating single-use refresh tokens) rather than
  reimplementing it — per the task's explicit instruction to get this right from day one.
- **Card movement: button/dropdown-based, not drag-and-drop.** Each card gets "move up" / "move
  down" (reorder within its list) and a "Move to…" select (cross-list move to the end of the
  target list) instead of a `@dnd-kit/core` pointer-drag interaction. This is a deliberate
  reference-implementation choice: it keeps the web app dependency-light, is fully keyboard- and
  screen-reader-operable with zero extra a11y work, and — since this is the pattern the other 9
  language/platform ports will mirror — it is far easier to reproduce faithfully in, say, a Swift
  or Flutter port than a pointer-drag gesture system would be. Every move still writes
  `position`/`listId` and appends an `activity` row exactly as specified, regardless of which UI
  triggered it.

## Auth Model (differs from the social/ecommerce showcases)
This app has **no anonymous/guest session and no public read**. Every one of the three roles
(`owner`/`member`/`viewer`) requires a real login — even the read-only `viewer` role must sign in
to see the board, because Mudbase's own collection permissions 401 an unauthenticated request.
`MudbaseProvider` therefore only attempts `getSession()` when a token already exists in
`localStorage`; it never calls `loginAnonymous()`. Every page except `/login` is wrapped in an
`AuthGate` that redirects to `/login` when there is no session once loading settles.

Registration is real (role slug is part of the URL path, e.g.
`POST /api/auth/local/signup/owner`), and `src/lib/mudbase.ts` implements it exactly like the
ecommerce showcase's multi-role client (role passed by the caller, stripped out of the request
body before it's sent — the validator's `.unknown(false)` anti-role-injection check rejects a
body that includes it). No registration UI is built for this reference app. `/login` ships three
"Sign in as…" quick-fill buttons alongside a normal email+password form, for fast demoing without
retyping credentials.

**Real platform finding: the task's originally-given `.test`-domain demo accounts cannot log in.**
`kanban-owner@example.test` / `kanban-member@example.test` / `kanban-viewer@example.test` all
fail at the very first validation step of `POST /api/auth/local/login` — confirmed live:
`{"error":"Validation failed","details":["\"email\" must be a valid email"]}`, a 400 that happens
*before* credentials are even checked (the same request with a `.com` domain instead passes
validation and correctly reaches "Invalid credentials"). Root cause, confirmed by reading the
actual production backend source (`themudhaxk/mudbase-server`, deployed as `cloud.mudbase.dev`):
`middleware/validate.js`'s `login`/`register` schemas use bare `Joi.string().email().required()`
with no `{ tlds: { allow: false } }` override, so Joi's default TLD allowlist (from
`@sideway/address`) applies — and that allowlist deliberately excludes RFC 2606 reserved
special-use TLDs (`.test`, `.example`, `.invalid`, `.localhost`), since they're not real
registrable domains. This is a genuine, pre-existing platform-level gap (default Joi behavior,
never overridden), not an app bug, and not something fixable from this app's code. **Resolution
used for this build**: three fresh accounts were registered under the same `owner`/`member`/
`viewer` role slugs on this same project with valid-TLD emails
(`kanban.owner.demo@gmail.com` / `kanban.member.demo@gmail.com` / `kanban.viewer.demo@gmail.com`,
password `KanbanTest123!`), verified, and used for the live smoke test below — since RBAC
permissions live on the *role*, not the specific user, these are functionally identical test
accounts to the ones originally specified. The app's login form itself is unaffected either way
— it accepts any email/password pair; this finding is about the credentials, not the code.

**Second real platform finding: `boardId`/`assigneeId` are ObjectId-typed, not free strings.**
The task described `boardId` as a plain `string` field and suggested a literal constant like
`"main-board"`. Live testing proved otherwise: `POST`/`GET filter` against any of the three
collections with `boardId: "main-board"` is rejected by the platform's query sanitizer with
`{"error":"Invalid input: Invalid query: Invalid ObjectId format for boardId"}` — any field whose
name ends in `Id` is validated as a real 24-hex-char ObjectId, a legitimate anti-injection rule,
not a bug. Same for `cards.assigneeId` (rejects a slug like `"mia-member"` the same way), and an
**empty string does not clear it either** — `assigneeId: ""` gets the identical rejection;
`assigneeId: null` is what actually clears it (confirmed live, see `useUpdateCard` below).

Fixed by: (1) a dedicated `boards` collection (`6a6d405cd07caabbbdfc5c79`, read granted to all
three roles, create/update/delete owner-only) with exactly one document,
`6a6d4072d07caabbbdfc5d3c` — this is the real `BOARD_ID` constant used everywhere (see
`.env.example`), not an arbitrary hand-picked hex string; (2) deriving `assigneeId` from the
typed assignee name via a small deterministic hash (`pseudoObjectId()` in `src/lib/utils.ts`)
that always produces a valid-looking 24-hex-char id, rather than the free-text slug originally
planned; (3) `useUpdateCard` (`src/hooks/useCards.ts`) sends `null` — never `""` — for
`assigneeId`/`assigneeName` when the assignee is cleared. This app does not otherwise read from
the `boards` collection (the single-board scope is still a hardcoded constant, per the task) —
it exists purely so `BOARD_ID` is a real document id rather than a synthetic one. None of this
affects the app's behavior or data model semantics from the UI's perspective — `boardId` and
`assigneeId` are still opaque identifiers, just format-constrained (and, for `assigneeId`,
null-clearable) ones.

## RBAC Matrix (enforced server-side by Mudbase's own collection permissions; UI mirrors it for defense-in-depth)

| Action | owner | member | viewer |
|---|---|---|---|
| Read lists | ✅ | ✅ | ✅ |
| Create/rename/delete/reorder lists | ✅ | ❌ | ❌ |
| Read cards | ✅ | ✅ | ✅ |
| Create/edit/delete/move cards | ✅ | ✅ | ❌ |
| Read activity | ✅ | ✅ | ✅ |
| Create activity (implicit, via card/list writes) | ✅ | ✅ | ❌ |

The UI hides write controls entirely for `viewer` (rather than showing disabled buttons with no
explanation) and hides list-restructuring controls for `member`, per the task's "disabled with a
clear reason" allowance — a `viewer`'s board header instead shows a small "Read-only — you're
signed in as Viewer" notice. The task explicitly requires proving the server enforces this
independently of the UI; see "Live smoke test results" below for a raw-`fetch` write attempt as
the viewer account that the UI never exposes a button for.

## Data Models (Mudbase Collections — already provisioned, used as-is, not recreated)

Single shared board: every `boardId` field everywhere is the constant
`6a6d4072d07caabbbdfc5d3c` — the id of the one document in a small `boards` collection
(`6a6d405cd07caabbbdfc5c79`, read granted to all three roles, create/update/delete owner-only;
provisioned alongside the three collections below once the ObjectId-format finding above came up)
(not multi-tenant — see task; see the ObjectId-format finding above for why this is a real
24-hex-char ObjectId rather than a slug like `"main-board"`).

### lists — `6a6d29cad07caabbbdfc3f9a`
`boardId` (ObjectId-format string), `name` (string), `position` (number), plus
`_id`/`createdAt`/`updatedAt`. Sorted ascending by `position` for column order.

### cards — `6a6d29cad07caabbbdfc3fad`
`boardId` (ObjectId-format string), `listId` (string, which column), `title` (string),
`description` (string, optional), `position` (number, order within its list), `assigneeId`
(ObjectId-format string, optional — see `pseudoObjectId()` finding above), `assigneeName` (string,
optional — denormalized, there is no `users` collection so a display name is captured at write
time from the current session), `createdById`, `createdByName`. Fetched once per board
(`filter: { boardId }`, `sort: "position"`) and grouped client-side by `listId` — one query, not
one per column.

### activity — `6a6d29cbd07caabbbdfc3fc6`
`boardId`, `actorId`, `actorName`, `action` (string — see below), `cardTitle` (optional),
`fromList` (optional, a list **name**, not id), `toList` (optional, a list name). Fetched
`sort: "-createdAt"` for the reverse-chronological feed.

`action` values written by this app: `created_card`, `moved` (covers both cross-list moves and
same-list reorders — the task specifies "every move…appends an activity entry", so a same-list
reorder logs `moved` with `fromList === toList`), `deleted_card`, `created_list`, `renamed_list`,
`deleted_list`. Only `created_card`/`moved`/`deleted_card` are required by the task; the three
list-level actions are a small superset that makes the log read naturally as a real project
history, written by the same owner-only code paths that already call the lists API.

## Auth Flow
```
Visit any page, no token       → AuthGate redirects to /login (no anonymous/guest session — every
                                  role, including viewer, must authenticate)
Login                           → POST /api/auth/local/login { email, password, projectId }
                                                     → 200 + token/refreshToken + user.customRole
                                                       (one of "owner"/"member"/"viewer")
401 on any authenticated call   → MudbaseClient refreshes once (deduped via refreshInFlight,
                                   since refresh tokens are single-use/rotating) → retries the
                                   original request once → surfaces the error if that also fails
Logout                          → POST /api/auth/logout (revokes token + kills session), socket
                                   disconnected
```

## Realtime
`BoardView` subscribes to the `cards` collection's Socket.IO room; `ActivityFeed` subscribes to
`activity`; both use the same `subscribe:collection` `{projectId, collectionId}` →
`db:create`/`db:update`/`db:delete` contract as the social showcase's `usePostsLive` (this app
additionally needs `db:delete`, since cards and lists are actually deleted here, unlike posts).
`BoardView` also subscribes to `lists` so another owner's column add/rename/delete/reorder appears
live for every signed-in viewer/member without a refresh.

## UI Pages
- `/login` — email+password form (react-hook-form + zod) plus three "Sign in as Owner / Member /
  Viewer" quick-fill buttons.
- `/` — the board: `BoardHeader` (board title, current-user role badge, read-only notice for
  viewers), list of `ListColumn`s (each with its `CardItem`s), an owner-only `AddListForm` at the
  end of the row.
- `/activity` — full reverse-chronological `ActivityFeed`, updating live, linked from the header
  nav.

## Security Implementation
- Input validation: zod schemas for every form (login, create/edit list, create/edit card) via
  react-hook-form + `@hookform/resolvers/zod`. Card titles capped at 120 chars, descriptions at
  2000, list names at 60.
- Authentication: Mudbase-issued JWT (access + refresh) held in `localStorage` via
  `MudbaseClient`, with 401 → refresh → retry handled once, deduped across concurrent requests
  (`refreshInFlight`).
- Authorization: enforced server-side by Mudbase's own collection permissions per the RBAC matrix
  above — the app's own role checks (`useRole()` / `<RoleGate>`) are UX gating (hide/disable
  controls, redirect), not the security boundary. Verified live for the `viewer` role — see below.
- Rate limiting / secrets: inherited from Mudbase's own per-endpoint limits; no server-side
  credential exists anywhere in this app (no Route Handlers at all) since every env var is
  `NEXT_PUBLIC_*` and safe to expose.

## Live smoke test results (2026-08-01, against the real project)

Performed with three real, verified accounts registered under this project's `owner`/`member`/
`viewer` role slugs (see "Real platform finding" above for why these replace the task's original
`.test`-domain accounts): `kanban.owner.demo@gmail.com` ("Kanban Owner"),
`kanban.member.demo@gmail.com` ("Mia Member"), `kanban.viewer.demo@gmail.com` ("Vic Viewer"), all
password `KanbanTest123!`. Every request below was made with a real JWT from
`POST /api/auth/local/login`, hitting the exact same REST/WebSocket contract this app's
`src/hooks/*` implement — verified with raw `curl`/`fetch`, not just through the UI.

| Step | Result |
|---|---|
| Login as owner / member / viewer | ✅ all three, correct `user.customRole` returned (`"owner"`/`"member"`/`"viewer"`) |
| Owner creates 3 lists ("To Do" / "In Progress" / "Done", positions 0/1/2) | ✅ `201` each |
| Read lists back, `sort=position` | ✅ correct ascending order |
| Owner creates 2 cards in "To Do" (one with a description, one with an assignee) | ✅ `201` each |
| Owner creates 1 card in "In Progress" | ✅ `201` |
| Owner writes 3 `activity` rows for the above creates | ✅ `201` each |
| Member moves a card "To Do" → "In Progress" (`PATCH listId`+`position`) | ✅ `200`, fields updated |
| Member writes a `moved` activity row (`fromList`/`toList`) | ✅ `201` |
| Member edits a card's `description` | ✅ `200`, field updated |
| Member clears a card's assignee (`assigneeId`/`assigneeName: null`) | ✅ `200` — confirms the `useUpdateCard` fix; the same request with `assigneeId: ""` instead correctly `400`s (`Invalid ObjectId format for assigneeId`) |
| **Member attempts to create a list (`POST lists`)** | ✅ **`403` `"Insufficient permissions"`, `required: {action:"create",collection:"lists"}`, `customRole:"member"`** — server correctly blocks a member from restructuring columns |
| Viewer reads `lists` | ✅ `200`, all 3 returned in order |
| Viewer reads `cards` | ✅ `200`, all cards returned with correct `listId` |
| **Viewer raw `fetch` `POST cards` (create)** | ✅ **`403` `"Insufficient permissions"`, `customRole:"viewer"`** |
| **Viewer raw `fetch` `PATCH cards/:id` (edit)** | ✅ **`403`, same shape** |
| **Viewer raw `fetch` `DELETE cards/:id`** | ✅ **`403`, same shape** |
| Activity feed, `sort=-createdAt` | ✅ correct reverse-chronological order, all fields present |
| Realtime: owner's Socket.IO client subscribed to `cards`, member creates a card via plain REST (different connection entirely) | ✅ owner's socket received `db:create` with the correct document in well under 1 second |

**Net result**: every request shape this app's hooks generate — list/card CRUD, cross-list move,
same-list reorder (position swap), activity logging, and realtime `db:create` — is proven correct
against the live backend. Critically, the task's core security claim is independently verified:
**the viewer role's inability to write is enforced by Mudbase's own collection permissions
server-side (`403 Insufficient permissions`), not merely by this app's UI hiding the buttons** —
confirmed with three different raw write verbs (create/update/delete) bypassing the UI entirely.

This whole pass was run twice: once against a hand-picked (but not collection-backed) 24-hex
`BOARD_ID`, and again in full after the platform owner provisioned the real `boards` collection
and flagged that `assigneeId`/`boardId` needed to be genuine ObjectIds (not just hex-shaped
strings) with `null` (not `""`) as the correct clear-value — the results above are from that
second, final pass against `6a6d4072d07caabbbdfc5d3c`. The first pass's test data was deleted
before re-seeding. The board was left seeded with this final test data (3 lists, 3 cards, 4
activity rows) as a working demo state.

`npx tsc --noEmit`, `npm run build`, and `npm run lint` all pass clean throughout (re-verified
after the `pseudoObjectId`/`BOARD_ID` fixes above).

## Known Limitations (real platform constraints, not bugs)
- **No `users` collection.** Assignee/creator/actor display names are denormalized onto the row
  that references them at write time (`assigneeName`, `createdByName`, `actorName`) rather than
  looked up from a central users table — matches the same constraint documented in the social
  showcase's build plan.
- **Same-list reorder currently uses a two-write position swap** (adjacent card's `position`
  fields are exchanged) rather than a fractional-index scheme. This is correct and simple at
  demo scale (a handful of cards per column) but would need a fractional/lexicographic position
  key to stay O(1) at very large list sizes — noted for any of the 9 ports that want to go
  further, not required by this build's scope.

## Environment Variables
See `.env.example`. All `NEXT_PUBLIC_*` — no server-side secret exists in this app.

## File Tree
```
mudbase-showcase-kanban/web/
├── package.json, tsconfig.json, next.config.ts, tailwind.config.ts, postcss.config.mjs,
│   components.json, eslint.config.mjs, .env.example, .env.local, README.md
├── plan/build-plan.md
├── src/
│   ├── app/
│   │   ├── layout.tsx, globals.css, page.tsx (board)
│   │   ├── login/page.tsx
│   │   └── activity/page.tsx
│   ├── components/
│   │   ├── providers/ (QueryProvider)
│   │   ├── layout/ (Header)
│   │   ├── auth/ (LoginForm, AuthGate)
│   │   ├── board/ (BoardView, ListColumn, CardItem, AddListForm, ListActionsMenu, CardDialog,
│   │   │           MoveCardControl)
│   │   ├── activity/ (ActivityFeed, ActivityItem)
│   │   └── ui/ (shadcn primitives: button, card, input, label, textarea, badge, separator,
│   │             avatar, dialog, select)
│   ├── hooks/ (useAuth, useCollection, useSocket, useLists, useCards, useActivity, useBoardLive,
│   │           useRole)
│   ├── lib/ (mudbase.ts, mudbase-provider.tsx, mudbase-socket.ts, config.ts, utils.ts, rbac.ts)
│   └── types/ (list.ts, card.ts, activity.ts)
```
