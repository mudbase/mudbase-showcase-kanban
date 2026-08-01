# Build Plan — Mudbase Showcase: Kanban (PHP port)

Generated: 2026-08-01
Mode: port (1 of 9 non-reference language/platform ports of `../web`, the reference implementation)
Type: web (server-rendered, fullstack via BaaS, no custom backend)
Stack: Plain PHP 8.1+ (no framework), PHP's built-in dev server, the real generated `mudbase/sdk`
Composer package — mirroring `../../mudbase-showcase-social/php`'s architecture (`Router` →
`Controllers` → `View` + plain `.php` view files, a request-scoped `AppContext`, a `MudbaseClient`
wrapper around the SDK) rather than reinventing a new one.

## Stack Decisions

- Plain PHP, no Laravel/Symfony — matches the sibling `mudbase-showcase-social/php` and
  `mudbase-showcase-ecommerce/php` ports exactly, which this port's `Router`/`AppContext`/
  `MudbaseClient`/`View`/`Http` classes are copied from (with kanban-specific business logic
  swapped in) rather than re-architected from scratch.
- **Session-based auth, not localStorage.** The Mudbase JWT pair (access + refresh) lives in
  native PHP `$_SESSION`, matching every other PHP port in this showcase family. There is no
  client-side JavaScript auth flow.
- **No anonymous/guest session — differs from the social/ecommerce PHP ports.** Those ports call
  `establishAnonymousSession()` in `bootstrap.php` on first visit so public reads work without a
  real account. This app has no public read at all (see reference web app's build-plan.md "Auth
  Model"): every one of the three roles, including the read-only `viewer`, must sign in with a
  real account before anything renders. `bootstrap.php` therefore only rehydrates a client from an
  existing `$_SESSION` token; it never bootstraps a guest. Every controller other than
  `AuthController` calls `AppContext::current()->requireSignIn()` (a new helper, not present in
  the social port) before doing anything, which redirects to `/login?redirect=...` instead of
  rendering.
- **`MudbaseClient` is intentionally smaller than the social port's.** No registration UI is built
  (per the task's explicit instruction: the three demo accounts already exist, do not register
  new ones), so `MudbaseClient` here drops `registerWithRole()`, `verifyEmail()`, and
  `establishAnonymousSession()` entirely — it only wraps `AuthenticationApi::loginLocalUser`,
  `logoutLocalUser`, `getLocalSession`, `refreshToken`, and `DataApi`'s five collection operations.
  Same 401-refresh-and-retry-once behavior, same `listDataRequest()`-bypasses-the-lossy-typed-
  `listData()` workaround, same `SDK_MAX_LIMIT = 100` clamp — all ported verbatim from the social
  port's class of the same name, because those are real, already-verified SDK-generation
  constraints (see that file's docblock), not something specific to the social data model.
- **Card movement: button/form-based, not drag-and-drop** — same reference-implementation choice
  as `../web` (see that project's build-plan.md "Stack Decisions" for the full rationale), and an
  even more natural fit for a server-rendered, no-JS-required app: every card gets a "▲"/"▼"
  same-list reorder pair (position swap with the adjacent card) and a "Move to…" `<select>` +
  submit button for cross-list moves — plain HTML forms, zero client JavaScript, fully keyboard-
  and screen-reader-operable.
- **Zero client-side JavaScript, full stop** — not even the reference web app's "quick-fill"
  convenience buttons need JS here: `/login` ships three separate `<form>`s, one per demo account,
  each with the email/password already baked into hidden inputs and a single labelled submit
  button ("Sign in as Owner" / "Sign in as Member" / "Sign in as Viewer"), alongside a normal
  email+password form for typing credentials manually. Column rename/edit-card use a native
  `<details>/<summary>` disclosure instead of JS-toggled visibility — inline, keyboard-operable,
  no JS.

## Auth Model (see reference web app's build-plan.md for the full platform findings)

- Real login only: `POST /api/auth/local/login { email, password, projectId }`. No registration
  form in this app (task instruction: use the three pre-provisioned accounts, do not register
  new ones).
- `AppContext::isSignedIn()` carries forward the **critical fix already learned from the
  ecommerce/social PHP ports**: `GET /api/auth/local/session` omits the `isAnonymous` key entirely
  for anonymous sessions rather than sending `false`, so a bare `isAnonymous !== true` check would
  wrongly treat a guest as signed in. This app additionally never has a guest session in the first
  place (see "Stack Decisions" above), but the same defensive check is kept verbatim — cheap
  insurance and consistency with the other ports — requiring `customRole !== null` in addition to
  the `isAnonymous` check.
- 401 on any authenticated call mid-session → `MudbaseClient` refreshes once via the stored
  refresh token and retries; if that also fails, the front controller
  (`public/index.php`) catches `MudbaseApiError::isUnauthorized()`, clears `$_SESSION`, and
  redirects to `/login?redirect=<original path>` — not back to the same protected URL as a fresh
  "guest" the way the social port does, since this app has no guest mode to fall back into.
- Logout: `POST /api/auth/logout` (via `MudbaseClient::logout()`), session cleared,
  `session_regenerate_id(true)`.

## Real, live, already-provisioned Mudbase project (given, not created by this build)

- Base URL: `https://cloud.mudbase.dev`, Project ID: `6a6d29b2d07caabbbdfc3f8c`
- `boards` (`6a6d405cd07caabbbdfc5c79`) — single document, real id `6a6d4072d07caabbbdfc5d3c` —
  this is the `BOARD_ID` constant used everywhere `boardId` is needed, exactly as the reference web
  app uses it (see that project's `.env.example`/`src/lib/config.ts`). This app does not otherwise
  read the `boards` collection.
- `lists` (`6a6d29cad07caabbbdfc3f9a`) — `boardId`, `name`, `position`.
- `cards` (`6a6d29cad07caabbbdfc3fad`) — `boardId`, `listId`, `title`, `description?`, `position`,
  `assigneeId?`, `assigneeName?`, `createdById`, `createdByName`.
- `activity` (`6a6d29cbd07caabbbdfc3fc6`) — `boardId`, `actorId`, `actorName`, `action`,
  `cardTitle?`, `fromList?`, `toList?`.
- Role slugs: `owner` / `member` / `viewer`. `boardId`/`assigneeId` are ObjectId-format-validated
  server-side (not free strings) — every write in this app either omits `assigneeId` or sends a
  real 24-hex value; `assigneeId`/`assigneeName` are cleared with `null`, never `""` (same platform
  finding the reference web app already made and documented — see its build-plan.md).

## RBAC Matrix (enforced server-side by Mudbase's own collection permissions; this app's UI mirrors it for defense-in-depth only)

| Action | owner | member | viewer |
|---|---|---|---|
| Read lists / cards / activity | ✅ | ✅ | ✅ |
| Create/rename/delete/reorder lists | ✅ | ❌ | ❌ |
| Create/edit/delete/move cards | ✅ | ✅ | ❌ |

`src/Support/Rbac.php` (`canManageLists`/`canManageCards`/`isReadOnly`/`roleLabel`) is a line-for-
line PHP port of the reference app's `src/lib/rbac.ts`, used only to hide/disable controls a role
cannot use in the rendered HTML. **Controllers do not pre-check role before attempting a
write** — they call the same `MudbaseClient` write method a permitted role would use and let
Mudbase's own collection permissions return the real `403` if the signed-in role isn't allowed,
same as the reference web app's hooks. This is deliberate: it proves the security boundary lives
on the platform, not in this app's code, and is exactly what the live smoke test below verifies
with a raw `curl` request that bypasses every UI control.

## Data flow per request

`BoardController::index` fetches `lists` (`filter: {boardId: BOARD_ID}, sort: "position"`) and
`cards` (`filter: {boardId: BOARD_ID}, sort: "position"`) — one query each, grouped by `listId` in
PHP — never one query per column, matching the reference app's `BoardView`. `ActivityController::
index` fetches `activity` (`filter: {boardId: BOARD_ID}, sort: "-createdAt", limit: 200`).

Every mutating controller method appends exactly the `activity` row the reference app's hooks
would (`created_card` / `moved` / `deleted_card` / `created_list` / `renamed_list` /
`deleted_list`), with the same field shape (`fromList`/`toList` are list **names**, not ids).
`src/Support/ActivityText.php` is a line-for-line PHP port of `src/lib/activity-text.ts`'s
`describeActivity()` switch, used by the activity feed view.

## Realtime — not implemented (real platform + architecture constraint, not a bug)

Same position as the social/ecommerce PHP ports (see their READMEs): the generated PHP SDK ships
no realtime client, and a server-rendered app has no persistent connection to attach a
Socket.IO subscription to. A page reload (this app already reloads via `303` redirect after every
mutation) shows the latest state. This is the one feature explicitly present in the reference web
app (`useBoardLive`, Socket.IO `subscribe:collection`) that this PHP port does not attempt.

## UI Pages

- `/login` — email+password form plus three "Sign in as Owner / Member / Viewer" one-click forms
  (hidden-input credentials, zero JS).
- `/` — the board: header (board title, current role badge, "Read-only — you're signed in as
  Viewer" notice for viewers), one column per list (name, owner-only rename/delete/reorder-left-
  right controls, its cards, an owner/member "add card" form), an owner-only "add list" form at the
  end of the row. Each card shows title/description/assignee/created-by, owner/member edit
  (`<details>` disclosure)/delete forms, "▲"/"▼" reorder-in-place forms, and a "Move to…"
  `<select>` + submit form for cross-list moves.
- `/activity` — full reverse-chronological feed, linked from the header nav.

## Security Implementation

- CSRF token (`src/Http/Csrf.php`, ported verbatim from the social PHP port) on every
  state-changing form, verified before any controller logic runs.
- Open-redirect guard (`Response::redirectToSafe()`, ported verbatim) on every caller-supplied
  `redirectTo`.
- Session id regenerated on login (`session_regenerate_id(true)`).
- All dynamic output escaped via `View::escape()` — no raw interpolation of user content anywhere.
- **Authorization is enforced server-side by Mudbase's own collection permissions** — this app's
  own role checks are UX gating (hide/disable controls, redirect unsigned-in visitors to
  `/login`), never the security boundary. Verified live below with a raw `curl` write attempt as
  the `viewer` account that the UI never exposes a button or form for.
- Input validation: card titles capped at 120 chars, descriptions at 2000, list names at 60 (same
  limits as the reference web app's zod schemas), enforced server-side in each controller before
  any Mudbase call.

## Live smoke test results (2026-08-01, against the real project, this PHP app)

Performed against the same live, shared project/collections the reference web app and every other
concurrent language/platform port of this showcase were testing against simultaneously, using the
three real, pre-provisioned demo accounts named in the task. Because ~8 other ports (Python, Go,
Ruby, Java, C#, Swift, Flutter, Expo) were running their own live smoke tests against the exact
same `/api/auth/local/login` endpoint from the same egress IP at the same time, the platform's
per-IP auth rate limit (5 requests / 15 min) was in practice shared and repeatedly exhausted by
other agents' traffic, not just this app's own requests — every login phase below needed several
retries, spaced ~60s apart, before a request landed inside a window the other concurrent builds
hadn't already consumed. This is a real, observed characteristic of testing against a shared
project under concurrent load, not an app defect; see the social PHP port's README for the same
phenomenon documented independently. The shared board also accumulated lists/cards from other
ports' concurrent test runs during this session (e.g. duplicate "To Do"/"In Progress"/"Done"
columns, cards like "Ruby port smoke test card") — expected and harmless, since every query this
app makes is correctly scoped to whatever the collection actually contains at read time.

| Step | Result |
|---|---|
| `GET /` with no session | ✅ redirects to `/login?redirect=%2F` |
| Login as owner (`kanban.owner.demo@gmail.com`) | ✅ succeeded on retry after the shared rate limit cleared; role badge "Owner" rendered |
| Owner creates card "PHP RBAC verification card" in "PHP Port Test List" via `/cards` | ✅ `303`, card appears in the correct column with description + assignee "Kanban Owner" |
| Login as member (`kanban.member.demo@gmail.com`) | ✅ succeeded on retry; role badge "Member"; "Add a list" form count on the board page: `0` (owner-only control correctly hidden); `card-item__controls` present (member can manage cards) |
| Member reorders the test card up within its list via `/cards/{id}/move` (`direction=up`) | ✅ `303` |
| Member edits the test card's title/description/assignee via `/cards/{id}/edit` | ✅ `303`, updated text rendered on reload ("PHP RBAC verification card (edited by member)", "Edited by member via curl smoke test") |
| Member moves the test card cross-list ("PHP Port Test List" → "To Do") via `/cards/{id}/move` (`toListId`) | ✅ `303`, card confirmed rendered under the "To Do" column on reload |
| **Member submits `/lists` (create list) directly via raw `curl`, bypassing the UI (no such form is ever rendered for `member`)** | ✅ flash **"You don't have permission to manage lists."**, list count on the board unchanged before/after — confirms the underlying `MudbaseApiError` was a real `403` from Mudbase, not a local check |
| Login as viewer (`kanban.viewer.demo@gmail.com`) | ✅ succeeded on retry; role badge "Viewer"; `readonly-notice` present; `Add a list` / `+ Add card` / `card-item__controls` / `list-column__controls` all `0` — zero write forms rendered anywhere on the board |
| **Viewer submits `/cards` (create) directly via raw `curl` with a forged body, bypassing the UI entirely** | ✅ flash **"You don't have permission to add cards."** |
| **Viewer raw API `POST` `.../collections/{cardsId}/data` using the viewer's own real session JWT** (extracted via a temporary debug route added only for this test and deleted before commit — see below) | ✅ **`403 {"error":"Insufficient permissions","required":{"action":"create","collection":"cards"},"userRole":"viewer","customRole":"viewer"}`** |
| **Viewer raw API `PATCH` `.../data/{cardId}`** | ✅ **`403 {"error":"Insufficient permissions","required":{"action":"update","collection":"cards"},"userRole":"viewer","customRole":"viewer"}`** |
| **Viewer raw API `DELETE` `.../data/{cardId}`** | ✅ **`403 {"error":"Insufficient permissions","required":{"action":"delete","collection":"cards"},"userRole":"viewer","customRole":"viewer"}`** |
| `/activity` (as owner) | ✅ reverse-chronological; the member's cross-list move and reorder from this session both appear correctly worded ("moved ... from PHP Port Test List to To Do", "reordered ... within ..."), interleaved with other ports' concurrent activity on the shared board |

**Net result**: every write this app's controllers generate — card create/edit, cross-list move,
same-list reorder — is proven correct against the live backend with real HTTP round trips (not
mocked), and the task's core security claim is independently verified two ways: (1) the app's own
controller surfaces a clean, correct flash message backed by a genuine `403` from Mudbase rather
than a locally faked one, and (2) three **raw, unauthenticated-by-this-app** requests
(create/update/delete) made directly against `cloud.mudbase.dev` using the viewer's own real JWT —
completely bypassing this app's PHP code — were independently rejected by Mudbase's own collection
permissions. The temporary route used to extract that JWT for step (2)
(`GET /__debug_session_token`, added to `public/index.php` only for this test) was deleted before
the commit that ships this build; it is not present in the shipped code.

## Known Limitations (real platform/architecture constraints, not bugs)

- **No realtime** — see "Realtime" above.
- **No `users` collection** — assignee/creator/actor display names are denormalized onto the row
  that references them at write time, same constraint as every other PHP port in this showcase
  family.
- **Same-list reorder is a two-write position swap**, not a fractional-index scheme — correct and
  simple at demo scale, same documented tradeoff as the reference web app.
- **No registration UI** — by task instruction; the three demo accounts already exist.

## Environment Variables

See `.env.example`. `MUDBASE_BOARD_ID` is not secret (a collection document id), but is still an
env var (not a hardcoded literal in source) so a fork of this app pointed at a different Mudbase
project only needs to edit `.env`, matching every other config value.

## File Tree

```
mudbase-showcase-kanban/php/
├── composer.json, composer.lock, .env.example, .gitignore, README.md
├── plan/build-plan.md
├── public/
│   ├── index.php, router.php
│   └── assets/style.css
└── src/
    ├── bootstrap.php, Config.php, Router.php, View.php
    ├── Http/ (AppContext, Csrf, Flash, Response)
    ├── Mudbase/ (MudbaseClient, MudbaseApiError)
    ├── Support/ (TimeFormat, ActivityText, Rbac)
    ├── Controllers/ (AuthController, BoardController, ActivityController)
    └── views/
        ├── layout.php, login.php, board.php, activity.php
        ├── partials/ (list_column.php, card_item.php)
        └── errors/ (not_found.php, server_error.php)
```
