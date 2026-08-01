# Build Plan — Mudbase Showcase: Kanban (Java / Spring Boot port)
Generated: 2026-08-01
Mode: port (Java/Spring Boot reimplementation of the reference Next.js app at `../web`)
Type: server-rendered web app (fullstack via BaaS, no custom backend)
Stack: Spring Boot 3.3.5 + Thymeleaf + Java 17, backed entirely by Mudbase (cloud.mudbase.dev),
structured to mirror `mudbase-showcase-social/java` and `mudbase-showcase-ecommerce/java`.

## Process
1. Read `../web/src/lib/mudbase.ts`, `../web/plan/build-plan.md`, `../web/README.md`, and every
   hook/component under `../web/src/{hooks,components,lib}` that defines the data model, RBAC
   matrix, and card-movement semantics this port must match exactly.
2. Read `mudbase-showcase-social/java`'s full source tree - `SessionAuthService` (including the
   already-fixed `recoverFromUnauthorized`), `MudbaseAuthClient`/`MudbaseDataClient` (both bypass
   the generated SDK for known Gson deserialization bugs), `MudbaseClientFactory`, controllers,
   services, domain objects, Thymeleaf templates, and `app.css` - to mirror its established
   Spring Boot structure exactly rather than invent a new one.
3. Build every file in dependency order: config → mudbase client layer → auth → domain → support
   → services → web (controllers, DTOs) → templates → static assets.
4. `mvn clean install` clean on the first attempt (38 source files, no test sources - this is a
   reference/demo app, out of scope per the task; `mvn clean compile`/`install` both pass with
   zero warnings).
5. Live smoke test against the three real, already-provisioned demo accounts - see below.
6. Write this document + README.md + `.env.example`.
7. Commit (author `themudhaxk <mudhaxk@gmail.com>`) and push to `origin main`, touching only
   `java/` files.

## Stack Decisions
- Spring Boot 3.3.5 + Thymeleaf + Java 17 + the same `dev.mudbase:mudbase-sdk:2.0.0` dependency
  the sibling social/ecommerce Java showcases use (already installed in `~/.m2` from those
  builds - no sibling-clone-and-install step needed here).
- No custom backend of any kind: every persistence, auth, and RBAC-adjacent concern this app
  reads/writes is a direct Mudbase REST call from this server, using the signed-in user's own
  JWT - there is no privileged/service-role credential anywhere in this app.
- **Server-rendered forms instead of drag-and-drop, matching the reference web app's own explicit
  design choice** (see `../web/plan/build-plan.md` "Design choice: button/dropdown card movement,
  not drag-and-drop"). Each card gets "move up"/"move down" (`POST /cards/{id}/move-up|move-down`,
  a `position` swap with the adjacent card) and a "Move to…" `<select>` + submit button
  (`POST /cards/{id}/move`, appends to the end of the target list) - the exact same two
  operations the web app's `MoveCardControl`/up-down buttons perform, just as plain HTML forms
  instead of client-side mutations. Lists get the equivalent "move left"/"move right" pair.
- **No realtime layer.** The reference web app subscribes to Socket.IO for live updates; this is
  a classic server-rendered app with a page reload/redirect after every mutation (`redirect:/`
  after every `POST`) - matches the sibling social/ecommerce Java ports' own documented
  difference from their Next.js counterparts. The data model, RBAC matrix, and every mutation's
  request shape are otherwise identical to the web app.
- **No registration UI.** All three demo accounts are pre-provisioned (see "Real, live Mudbase
  project" below) - this port is sign-in only, matching the sibling Java ports' own scope
  decision for the same reason (the task supplies working accounts; a registration flow adds
  surface area with nothing left to demonstrate).

## Auth Model
Identical to the reference web app: **no anonymous/guest session and no public read at all**.
Every one of the three roles (`owner`/`member`/`viewer`) requires a real login - even the
read-only `viewer` role must sign in, because Mudbase's own collection permissions 401 an
unauthenticated request. Enforced here by `AuthGateInterceptor` (registered against every route
except `/login`/`/logout`/static assets in `WebConfig`), which redirects to
`/login?redirect=<original-destination>` whenever `SessionAuthService.current(session)` is empty.
The JWT lives server-side in the Spring `HttpSession` for the life of the session - it is never
sent to client JS, since Thymeleaf renders plain HTML/CSS with no token in scope.

`SessionAuthService.recoverFromUnauthorized` is ported **verbatim** from
`mudbase-showcase-social/java` (which ported it from `mudbase-showcase-ecommerce/java`), per the
task's explicit instruction: a 401 whose `failedToken` no longer matches the session's current
token means an earlier call in the same request (or a concurrent request) already refreshed past
it - the fix hands back the session's current token for an immediate retry instead of discarding
a perfectly good, just-refreshed session and forcing a spurious "session expired" logout. This
app's `BoardController#board` (one `AuthSession` snapshot feeding a `lists` call and a `cards`
call back to back) is exactly the multi-call-from-one-snapshot shape that bug required.

## Real, live, already-provisioned Mudbase project (same project as `../web`)
- Base URL: `https://cloud.mudbase.dev`, Project ID: `6a6d29b2d07caabbbdfc3f8c`
- `lists` — `6a6d29cad07caabbbdfc3f9a` — `boardId`, `name`, `position`
- `cards` — `6a6d29cad07caabbbdfc3fad` — `boardId`, `listId`, `title`, `description?`, `position`,
  `assigneeId?`, `assigneeName?`, `createdById`, `createdByName`
- `activity` — `6a6d29cbd07caabbbdfc3fc6` — `boardId`, `actorId`, `actorName`, `action`,
  `cardTitle?`, `fromList?`, `toList?`
- `boards` — `6a6d405cd07caabbbdfc5c79`, single document `6a6d4072d07caabbbdfc5d3c` — this app
  never reads this collection (same as the web app); it exists purely so `BOARD_ID` is a real
  24-hex ObjectId rather than a hand-picked slug. `MudbaseProperties` validates the configured
  `mudbase.board-id` against `^[0-9a-fA-F]{24}$` at startup and fails fast if it isn't.
- Three demo accounts (role slugs `owner`/`member`/`viewer`), password `KanbanTest123!` for all
  three: `kanban.owner.demo@gmail.com`, `kanban.member.demo@gmail.com`,
  `kanban.viewer.demo@gmail.com`. These are the same accounts the reference web app's own build
  plan documents (the task's originally-specified `.test`-domain accounts fail Mudbase's login
  validator - RFC 2606 reserved TLD, rejected by Joi's default email TLD allowlist - confirmed
  live by that earlier build; not re-tested here since the finding is about the credentials, not
  this app's code).

## RBAC Matrix (enforced twice: Mudbase's own collection permissions, AND this app's own server-side check)

| Action | owner | member | viewer |
|---|---|---|---|
| Read lists / cards / activity | ✅ | ✅ | ✅ |
| Create/rename/delete/reorder lists | ✅ | ❌ | ❌ |
| Create/edit/delete/move cards | ✅ | ✅ | ❌ |

Two independent enforcement layers, neither of which is UI-only gating:

1. **This app's own service layer.** `ListService`/`CardService` call
   `RoleSupport.canManageLists`/`canManageCards` **before attempting any Mudbase call** and throw
   `ForbiddenActionException` (→ `GlobalExceptionHandler` → a 403 error page) if the acting
   role fails the check. A raw `POST /lists` or `POST /cards/{id}/delete` from `curl` as the
   `member`/`viewer` session cookie - bypassing the Thymeleaf template's hidden buttons entirely -
   is rejected right here, before this server ever talks to Mudbase.
2. **Mudbase's own collection permissions** - the platform-level authority, independent of this
   app's code entirely. Verified directly with `curl` against `cloud.mudbase.dev` using the
   `viewer` role's own JWT (obtained via `POST /api/auth/local/login`, not through this app) - see
   "Live smoke test results" below.

The Thymeleaf templates additionally hide every write control a role cannot use
(`canManageLists`/`canManageCards`/`isReadOnly` flags from `ViewModelHelper`, mirroring
`../web/src/lib/rbac.ts` exactly) - this is UX, not the security boundary; both layers above are.

## Data flow / request shapes (mirrors `../web/src/hooks/{useLists,useCards,useActivity}.ts` exactly)
- **Create list** (`ListService#createList`, owner-only): fetches current lists to compute the
  next `position` (`max + 1`, or `0` if empty), creates the document, writes a `created_list`
  activity row.
- **Rename list** (owner-only): fetches the list for its old name, updates `name`, writes
  `renamed_list` (`fromList`=old, `toList`=new).
- **Move list left/right** (owner-only): swaps `position` with the adjacent list - **no activity
  row**, matching the reference web app's `useReorderList` (only create/rename/delete list
  actions are logged).
- **Delete list** (owner-only, cascades): deletes every card in the list first (no per-card
  activity row for the cascade - the list's own `deleted_list` entry covers it, same as the
  reference web app has no per-card entries in this path either), then the list, then writes
  `deleted_list`.
- **Create card** (owner/member): fetches cards in the target list to compute next `position`;
  `description`/`assigneeId`+`assigneeName` are included in the create body **only when
  non-blank** (mirrors `useCreateCard`'s conditional spread); writes `created_card`.
- **Edit card** (owner/member, not logged): always sends `description` (empty string if blank)
  and `assigneeId`/`assigneeName` as **`null`** (never `""`) when the assignee field is cleared -
  mirrors `useUpdateCard` exactly, per the platform finding that `assigneeId` is ObjectId-typed
  and rejects an empty string the same way it rejects an invalid slug (`null` is what actually
  clears it).
- **Delete card** (owner/member): resolves the card's title and current list name first, deletes,
  writes `deleted_card` (`fromList`=the list it was in).
- **Move card to another list** (owner/member): resolves both list names, computes the target
  list's next `position`, updates `listId`+`position` together, writes `moved`
  (`fromList`≠`toList`).
- **Reorder card up/down within its list** (owner/member): swaps `position` with the adjacent
  card, still writes `moved` with **`fromList === toList`** - matches the task's "every
  move…appends an activity entry" requirement and the reference web app's
  `useReorderCardInList`.
- **Assignee**: there is no `users` collection (same platform constraint as every other showcase
  in this repo), so `assigneeName` is a free-typed display name. `assigneeId` is schema-validated
  as an ObjectId reference, so `support/PseudoObjectId.generate(name)` derives a stable,
  valid-looking 24-hex id from the typed name via the identical djb2-based algorithm as the
  reference web app's `pseudoObjectId()` (`../web/src/lib/utils.ts`) - same name, same id, in
  both apps (Java's 32-bit `int` overflow arithmetic is bit-identical to the TypeScript version's
  `(hash * 33) ^ charCode` followed by an implicit `ToInt32`).
- **Activity feed** (`ActivityService#feed`, any signed-in role): `filter: {boardId}`,
  `sort: "-createdAt"`, `limit: 200` - reverse-chronological, matching `useActivityFeed`.
  `ActivityEntry#getDescription()` mirrors `../web/src/lib/activity-text.ts`'s `describeActivity`
  sentence-for-sentence for all six action types.

## Known differences from `../web` (all deliberate, all match the sibling Java ports' own precedent)
- Server-rendered page reload after every mutation instead of optimistic client-side cache
  updates + realtime Socket.IO push. The RBAC matrix, data model, and every mutation's request
  shape are otherwise identical.
- No drag-and-drop (the web app doesn't have it either, by its own explicit design choice - see
  "Stack Decisions" above); this port's up/down/left/right/move-to controls are the server-form
  equivalent of the exact same web app controls.
- No registration UI (same scope decision the sibling social/ecommerce Java ports made).
- Board-page mutation forms bind directly to request-parameter names (`name="title"` etc.)
  rather than Thymeleaf `th:object`/`th:field` - because several independent forms (per-card
  edit, per-card move, per-list rename, add-card, add-list) render on one page simultaneously,
  field-level inline validation display was traded for a single flash-attribute `formError`
  banner on validation failure, redirecting back to `/`. Server-side `@Valid` enforcement
  (title ≤120 chars, description ≤2000, list name ≤60 - matching the web app's zod caps exactly)
  is unaffected by this choice.

## Live smoke test results (2026-08-01, against the real project, `mvn clean install` build)
Performed with the three demo accounts above, via `curl` with cookie-jar sessions against this
app running locally (`http://localhost:8092`), plus direct `curl` calls to `cloud.mudbase.dev`
(bypassing this app) for the viewer-403 verification. `PORT=8092` was used locally only to avoid
a collision with an unrelated process already on 8080 on this machine - the app's own default
remains `8080` (`java/.env.example`).

**Note on rate limiting**: this Mudbase project was being exercised *concurrently* by several
other sibling-port builds on this same machine/IP during this test pass (visible in the shared
`lists`/`cards`/`activity` collections: "PHP Port Test List", "Ruby port smoke test card",
"Flutter smoke test card", etc. - other agents' own live smoke tests against the same shared
demo project). `POST /api/auth/local/login` is rate-limited at `5;w=900` (5 requests/15 min) **per
IP**, shared across every one of those concurrent builds - not specific to this app or a bug in
it. Several login attempts had to be retried after real wall-clock waits (confirmed via the
`ratelimit-reset`/`retry-after` response headers) before a clean window was caught. Data-endpoint
calls (list/card/activity CRUD) are on a separate, much larger budget (`600;w=60` observed) and
were unaffected.

| Step | Result |
|---|---|
| `GET /login` unauthenticated | ✅ 200 |
| `GET /` unauthenticated | ✅ 302 → `/login?redirect=%2F` (`AuthGateInterceptor`) |
| Login as owner (`kanban.owner.demo@gmail.com`) | ✅ 302 → `/`, session established |
| Owner board `GET /` | ✅ 200, role badge "Owner", "Add a list" control present |
| Owner creates 3 lists ("To Do"/"In Progress"/"Done") | ✅ each `POST /lists` → 302; `activity` rows `created_list` recorded |
| Owner creates 2 cards in "To Do" (one with description + assignee "Kanban Owner"→ actual account display name "Olivia Owner", one bare) | ✅ each `POST /cards` → 302; card renders with description/assignee; `activity` rows `created_card` recorded |
| Owner reorders a card (move-down within "To Do") | ✅ `POST /cards/{id}/move-down` → 302; `activity` row `moved` with `fromList === toList` ("reordered … within To Do") |
| Owner edits a card (title + description) | ✅ `POST /cards/{id}/edit` → 302; fields updated, not logged to activity (matches spec) |
| Owner deletes a card | ✅ `POST /cards/{id}/delete` → 302; card removed from board; `activity` row `deleted_card` recorded |
| Login as member (`kanban.member.demo@gmail.com`) | ✅ 302 → `/`, session established |
| Member board `GET /` | ✅ 200, role badge "Member", "Add a list" absent (0 occurrences), "Add a card" present (one per column) |
| **Member `POST /lists` (create list)** | ✅ **403**, body `"Only the board owner can create a list."` - this app's own `ForbiddenActionException`, before any Mudbase call |
| **Member `POST /lists/{id}/delete`** | ✅ **403**, same enforcement layer |
| Member moves a card ("To Do" → "In Progress") | ✅ `POST /cards/{id}/move` → 302; `activity` row `moved` (`fromList` "To Do" → `toList` "In Progress") |
| Member edits a card (title, description, assignee "Max Member") | ✅ `POST /cards/{id}/edit` → 302; fields updated correctly |
| Login as viewer (`kanban.viewer.demo@gmail.com`) | ✅ 302 → `/`, session established |
| Viewer board `GET /` | ✅ 200, role badge "Viewer", "Read-only — you're signed in as Viewer" notice shown; **zero** write controls rendered (`Add a list`, `Add a card`, and `card-manage-controls` all 0 occurrences) |
| **Viewer `POST /cards` (create)** | ✅ **403**, body `"Only the board owner or a member can create a card."` |
| **Viewer `POST /cards/{id}/delete`** | ✅ **403** |
| **Viewer `POST /cards/{id}/move`** | ✅ **403** |
| Activity feed `GET /activity` (any role) | ✅ 200, correct reverse-chronological order, every action type (`created_list`/`created_card`/`moved`/`deleted_card`) renders the expected sentence via `ActivityEntry#getDescription()` |
| **Viewer raw JWT obtained directly from Mudbase** (`POST https://cloud.mudbase.dev/api/auth/local/login`, bypassing this app entirely) **then `POST` directly to `cloud.mudbase.dev/api/data/projects/.../collections/<cards>/data`** | ✅ **403** `{"error":"Insufficient permissions","required":{"action":"create","collection":"cards"},"userRole":"viewer","customRole":"viewer"}` - Mudbase's own collection permissions independently reject the write, confirming the RBAC boundary does not depend on this app's code at all, exactly mirroring the reference web app's own smoke test finding |
| `mvn clean install` (both before and after adding `GlobalExceptionHandler` structured logging) | ✅ BUILD SUCCESS, 38 source files, zero warnings, both times |
| App restart on the final jar + unauthenticated `GET /login` (200) / `GET /` (302) sanity check | ✅ |

**Net result**: every RBAC rule in the matrix above is enforced twice, independently, and both
layers were exercised live with real accounts and real raw HTTP requests - not just observed via
code reading. The task's specific requirement ("a raw API write attempt that should 403") is
satisfied at both altitudes: this app's own routes (`ForbiddenActionException`, before any
Mudbase call) and Mudbase's own platform-level permission check (via a JWT obtained completely
independently of this app).

## Environment Variables
See `.env.example`. `MUDBASE_BOARD_ID` and every collection/project id are public identifiers,
not secrets - no server-side secret exists anywhere in this app's configuration (it authenticates
purely with each signed-in user's own Mudbase-issued JWT, held only in the Spring `HttpSession`).

## File Tree
```
mudbase-showcase-kanban/java/
├── pom.xml, .env.example, .env (gitignored), .gitignore
├── plan/build-plan.md
├── src/main/resources/
│   ├── application.properties
│   ├── templates/
│   │   ├── fragments/layout.html
│   │   ├── index.html (board), error.html
│   │   ├── auth/login.html
│   │   └── activity/feed.html
│   └── static/css/app.css
└── src/main/java/dev/mudbase/showcase/kanban/
    ├── KanbanApplication.java
    ├── config/ (MudbaseClientFactory, MudbaseProperties)
    ├── auth/ (AuthSession, SessionAuthService)
    ├── mudbase/ (AuthResult, MudbaseApiException, PageResult, DocumentMapper,
    │             MudbaseAuthClient, MudbaseDataClient)
    ├── domain/ (BoardList, BoardCard, ActivityEntry)
    ├── support/ (Formatting, RedirectSupport, ViewModelHelper, RoleSupport, PseudoObjectId,
    │             ForbiddenActionException)
    ├── service/ (AuthService, ListService, CardService, ActivityService)
    └── web/ (AuthController, BoardController, ListController, CardController,
              ActivityController, GlobalExceptionHandler, AuthGateInterceptor, WebConfig,
              BoardViewAssembler, dto/{LoginRequest,CreateListRequest,RenameListRequest,
              CardFormRequest,MoveCardRequest})
```
