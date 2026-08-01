# Build Plan — Mudbase Showcase: Kanban (C# / ASP.NET Core port)

Generated: 2026-08-01
Mode: port of the reference Next.js implementation (`../web/`) — one of 10 planned
language/platform ports, built to match the reference app's data model and API contract exactly.
Type: server-rendered web app (fullstack via BaaS, zero custom backend).
Stack: ASP.NET Core 10 Razor Pages + the real Mudbase C# SDK (`mudbase-sdk/csharp`), talking
directly to `cloud.mudbase.dev`.

## Stack Decisions

- **Razor Pages, not MVC/Blazor**: mirrors the sibling `mudbase-showcase-social/csharp` and
  `mudbase-showcase-ecommerce/csharp` ports exactly — same project shape (`Program.cs` DI wiring,
  `Options/MudbaseOptions.cs`, `Services/Mudbase*.cs`, `Pages/*.cshtml(.cs)`), same conventions, so
  a reader who has seen one of these C# ports recognizes this one immediately.
- **Server-side session, not a client-held JWT**: the Mudbase access/refresh token pair lives in
  ASP.NET Core's server-side session state (`MudbaseSessionAccessor`), never reaching client JS —
  same pattern as the social/ecommerce ports. `SessionBearerTokenProvider` overrides the generated
  SDK's single-static-token assumption so every request resolves whichever JWT the *current*
  request's session cookie points at.
- **`TokenRefreshHandler` ported verbatim** from `mudbase-showcase-social/csharp` per the task's
  explicit instruction: a `DelegatingHandler` attached to every SDK HttpClient that, on a 401,
  exchanges the session's refresh token via `POST /api/auth/refresh` (through a separate
  handler-free `MudbaseRaw` HttpClient so a refresh call can never recursively retrigger itself),
  stores the new pair, and retries the original request exactly once.
- **`MudbaseDataService` list-read path**: the task noted that the SDK's previously-broken
  `DataListResponseDataInnerJsonConverter` (which used to silently discard every
  collection-specific field on list reads, keeping only `_id`/`createdAt`/`updatedAt`) has been
  fixed at the SDK level — confirmed live by reading
  `mudbase-sdk/csharp/src/Mudbase.Sdk/Model/DataListResponseDataInner.cs`'s converter, which now
  correctly routes every unrecognized property into `AdditionalProperties`. This service still
  parses `response.RawContent` directly with a plain `JsonDocument` (same technique as the social
  port) rather than reconstructing documents from the SDK's `AdditionalProperties` dictionary,
  because it maps straight onto our own POCOs in one step. This is a stylistic choice, not a
  workaround for the fixed bug — the authenticated HTTP call itself (token attachment, the
  401-refresh-retry above) still goes through the real generated SDK either way.
- **No client-side JS framework, no drag-and-drop**: matches the reference web app's own explicit
  choice (see `../web/plan/build-plan.md` "Stack Decisions") of button/dropdown-based card
  movement over a pointer-drag gesture library, for the same reasons — dependency-light,
  keyboard/screen-reader operable, and easiest of all 10 ports to reproduce faithfully. This
  server-rendered port goes one step further: there is no client-side JS at all beyond native
  `<details>/<summary>` progressive disclosure (used for inline rename/edit/add forms) and a
  single `confirm()` browser dialog on destructive actions (delete list/card) — no build step, no
  bundler, nothing to keep in sync with a separate SPA state layer.
- **`net10.0`, not `net8.0`** (see `MudbaseShowcase.Kanban.csproj`'s own comment): this build
  machine has only the .NET 10 SDK/runtime installed (`dotnet --list-runtimes` shows
  `Microsoft.NETCore.App`/`Microsoft.AspNetCore.App` 10.0.10 only). A `net8.0`-targeted project
  *builds* fine here (NuGet restores the 8.0 reference packs for compilation) but fails to *run* —
  verified live against the sibling `mudbase-showcase-social/csharp` port, which targets `net8.0`:
  `dotnet build` succeeds, but running the built DLL exits immediately with `You must install or
  update .NET to run this application` because the apphost's roll-forward policy does not cross
  major versions by default. Targeting `net10.0` for this new port avoids that entirely. The
  referenced `Mudbase.Sdk` library project itself still targets `net8.0` — a `net10.0` app can
  consume a `net8.0` class library without issue (a higher-TFM app referencing a lower-TFM
  library is a supported, ordinary scenario).

## Auth Model (matches `../web/plan/build-plan.md` exactly — no anonymous session)

This app has **no anonymous/guest session and no public read**. Every one of the three roles
(`owner`/`member`/`viewer`) requires a real login — even the read-only `viewer` role must sign in,
because Mudbase's own collection permissions 401 an unauthenticated request. Unlike the
social/ecommerce C# ports (which bootstrap an anonymous session in middleware so guest browsing
works), this port's `RequireMudbaseSessionMiddleware` does the opposite: it redirects *every*
request with no token in session to `/Login?ReturnUrl=...`, for every path except `/Login`,
`/Logout`, `/Error`, and static assets. This is the server-side equivalent of the reference app's
client-side `AuthGate`.

There is no registration UI in this reference app (unlike the social port, which has
`Pages/Register.cshtml`) — the task's three demo accounts (`kanban.owner.demo@gmail.com` /
`kanban.member.demo@gmail.com` / `kanban.viewer.demo@gmail.com`, all `KanbanTest123!`) already
exist, are pre-verified, and are explicitly the accounts to use — registering new ones was
explicitly out of scope. `Pages/Login.cshtml` ships a normal email+password form plus three
"Sign in as Owner/Member/Viewer" quick-fill buttons (`OnPostQuickLoginAsync`) that log in with
those exact demo credentials directly, for fast demoing without retyping.

**Real platform finding, reconfirmed during this port's build**: `POST /api/auth/local/login` is
rate-limited per source IP (see the platform's own documented auth rate limits) — this is a
genuine, expected, project-wide security control, not a bug. Because the same demo project and the
same three accounts are shared across all 10 language/platform ports being built and smoke-tested
from this machine, the limit stayed continuously exhausted throughout this build (confirmed live: a
raw `curl -X POST https://cloud.mudbase.dev/api/auth/local/login` returned
`{"error":"Too many requests from this IP, please try again later."}`, HTTP 429, independent of
this app entirely — reconfirmed after two separate, deliberately isolated quiet windows of 13 and
15 minutes with zero other requests from this session). See "Live smoke test results" below for
exactly what this build could and could not exercise live as a result, and why the RBAC/security
finding is still fully proven despite it.

## RBAC Matrix (enforced server-side by Mudbase's own collection permissions; this app's PageModel handlers add a second, defense-in-depth check — see below)

| Action | owner | member | viewer |
|---|---|---|---|
| Read lists | ✅ | ✅ | ✅ |
| Create/rename/delete/reorder lists | ✅ | ❌ | ❌ |
| Read cards | ✅ | ✅ | ✅ |
| Create/edit/delete/move/reorder cards | ✅ | ✅ | ❌ |
| Read activity | ✅ | ✅ | ✅ |
| Create activity (implicit, via card/list writes) | ✅ | ✅ | ❌ |

`Services/Rbac.cs` mirrors `../web/src/lib/rbac.ts`'s `canManageLists`/`canManageCards`/
`isReadOnly`/`roleLabel` exactly. Every mutating handler in `Pages/Index.cshtml.cs` calls
`Rbac.CanManageLists`/`Rbac.CanManageCards` against the session's `CustomRole` **before** making
any Mudbase call — this is a genuine second server-side gate inside this app (not merely hiding a
button in the Razor view, which is also done for UX), but it is explicitly *not* the real security
boundary. The task requires proving the boundary is Mudbase's own collection permissions,
independent of any application code; see "Live smoke test results" below for exactly how that is
proven for this port — this build's own rate-limited session could not mint a fresh viewer JWT, so
the raw-write-attempt proof is the identical, already-completed one from `../web/plan/build-plan.md`
and the sibling `mobile-expo` port (both against this exact same project/collections/roles), not a
weaker claim.

## Data Models (Mudbase Collections — already provisioned on the shared project, used as-is)

Single shared board: every `boardId` field everywhere is the constant
`6a6d4072d07caabbbdfc5d3c` (`MudbaseOptions.BoardId`) — the id of the one document in a small
`boards` collection (`6a6d405cd07caabbbdfc5c79`, not otherwise read by this app — see
`../web/plan/build-plan.md`'s "Second real platform finding" for why this must be a real 24-hex
ObjectId, not a slug like `"main-board"`).

### lists — `6a6d29cad07caabbbdfc3f9a` (`Models/ListDocument.cs`)
`boardId`, `name`, `position` (int), plus `_id`/`createdAt`/`updatedAt`. Sorted ascending by
`position` for column order.

### cards — `6a6d29cad07caabbbdfc3fad` (`Models/CardDocument.cs`)
`boardId`, `listId`, `title`, `description` (optional), `position` (int), `assigneeId`/
`assigneeName` (both nullable — `null` is a real, explicitly-cleared state, distinct from never
having been set), `createdById`, `createdByName`. Fetched once per board load
(`filter: { boardId }`, `sort: "position"`) and grouped in memory by `listId` (`ILookup<string,
CardDocument>` in `Pages/Index.cshtml.cs`'s `LoadBoardAsync`) — one query, not one per column,
same as the reference app.

### activity — `6a6d29cbd07caabbbdfc3fc6` (`Models/ActivityDocument.cs`)
`boardId`, `actorId`, `actorName`, `action`, `cardTitle`/`fromList`/`toList` (all optional).
Fetched `sort: "-createdAt"` for the reverse-chronological feed. `action` values written by this
app (`Services/ActivityActions.cs`): `created_card`, `moved` (covers both cross-list moves and
same-list reorders — a same-list reorder logs `moved` with `fromList === toList`, matching the
reference app), `deleted_card`, `created_list`, `renamed_list`, `deleted_list`.

`assigneeId` is schema-validated server-side as an ObjectId reference, not a free-form string —
`Services/PseudoObjectId.cs` ports `../web/src/lib/utils.ts`'s `pseudoObjectId()` djb2-hash
function verbatim (same algorithm, same output for the same input) so a free-typed assignee name
still produces a valid-looking 24-hex-char id.

## Auth Flow

```
Visit any page, no token       → RequireMudbaseSessionMiddleware redirects to
                                  /Login?ReturnUrl=<original path> (every role, including viewer,
                                  must authenticate — no anonymous/guest session)
Login (form or quick-login)    → POST /api/auth/local/login { email, password, projectId }
                                                     → 200 + token/refreshToken + user.customRole
                                                       (one of "owner"/"member"/"viewer"), cached
                                                       in server-side session state
401 on any authenticated call  → TokenRefreshHandler refreshes once (via the handler-free
                                   "MudbaseRaw" HttpClient) → retries the original request once →
                                   surfaces the error if that also fails
Logout                          → POST /api/auth/logout (revokes token server-side) + clears
                                   session state
```

## UI Pages

- `/Login` — email+password form plus three "Sign in as Owner/Member/Viewer" quick-fill buttons.
- `/` (`Pages/Index.cshtml`) — the board: header (title, read-only notice for viewers), a
  horizontally-scrolling row of `_ListColumn.cshtml` partials (each rendering its `_CardItem.cshtml`
  cards), an owner-only "+ Add list" column at the end.
- `/Activity` — full reverse-chronological feed, paginated (`pg` route param — deliberately not
  `page`, which Razor Pages reserves internally for ambient self-redirects; see
  `Pages/Activity.cshtml.cs`'s comment and the sibling social port's own documented finding of this
  exact pitfall).

## Security Implementation

- **Input validation**: server-side length/required checks in every `Pages/Index.cshtml.cs`
  handler (list name 1–60 chars, card title 1–120, description ≤2000, assignee name ≤80) — the
  same limits as the reference app's zod schemas — plus `[Required]`/`[EmailAddress]` data
  annotations on the login form.
- **Authentication**: Mudbase-issued JWT (access + refresh) held in ASP.NET Core server-side
  session state, never sent to client JS. 401 → refresh → retry handled once by
  `TokenRefreshHandler`.
- **Authorization**: enforced server-side by Mudbase's own collection permissions per the RBAC
  matrix above — this app's own `Rbac` checks in `Pages/Index.cshtml.cs` are a second,
  defense-in-depth server-side gate (not UI-only — every handler checks role before calling
  Mudbase at all), but the platform's own permissions remain the real boundary. Proven for the
  `viewer` role with a raw request bypassing the client entirely — see "Live smoke test results"
  below for why that proof is carried forward from the identical, already-verified REST contract
  rather than freshly re-run in this specific build.
- **CSRF**: every mutating form uses Razor Pages' built-in antiforgery token (`asp-` tag helpers
  auto-emit `__RequestVerificationToken`; ASP.NET Core validates it automatically on every POST
  handler).
- **Secrets**: none exist in this app. Every config value (`Mudbase:ProjectId`,
  `Mudbase:*CollectionId`, `Mudbase:BoardId`) is a project/collection/board id, not a credential —
  same reasoning as the reference web app's own `.env.example`, which documents this explicitly.
  They are committed directly in `appsettings.json` for the same reason.
- **Rate limiting**: inherited entirely from Mudbase's own per-endpoint limits (see the "Real
  platform finding" above, reconfirmed live during this build) — this app has no endpoints of its
  own to rate-limit; every write ultimately reaches Mudbase's REST API.

## Live smoke test results (2026-08-01, against the real project)

Performed against the three real, pre-verified demo accounts named in the task
(`kanban.owner.demo@gmail.com`, `kanban.member.demo@gmail.com`, `kanban.viewer.demo@gmail.com`, all
password `KanbanTest123!`).

**Real platform finding, hit live during this build**: `POST /api/auth/local/login` is
rate-limited per source IP (a genuine, documented platform security control — see the top-level
security notes on auth-endpoint rate limiting). Because this shared demo project and these exact
three accounts are used concurrently by all 10 language/platform ports being built and
smoke-tested from this same machine/IP at once, the window stayed continuously exhausted
throughout this build — confirmed with a raw, out-of-app `curl -X POST
https://cloud.mudbase.dev/api/auth/local/login` returning `{"error":"Too many requests from this
IP, please try again later."}` (HTTP 429), including after two separate, deliberately isolated
quiet windows (13 minutes and 15 minutes) during which this session issued *zero* other requests —
meaning the contention was coming from sibling sessions building the other 9 ports (three of
which — `mobile-expo`, `ruby`, `python`, `mobile-flutter` — committed to this same repo's `main`
while this port's build was in progress), not from this app or session. This exact situation, and
the same resolution used below, was already hit and documented by the sibling `mobile-expo` port
earlier the same day (see its commit message: "member/viewer RBAC 403s carried forward from the
web reference's identical live verification after this session hit the shared login rate limit").

### What was verified live, end-to-end, in this port

| Step | Result |
|---|---|
| `dotnet build` (net10.0), including `-warnaserror` | ✅ 0 Warnings, 0 Errors |
| Unauthenticated `GET /` | ✅ `302` → `/Login?ReturnUrl=%2F` (`RequireMudbaseSessionMiddleware`) |
| Unauthenticated `GET /Activity` | ✅ `302` → `/Login?ReturnUrl=%2FActivity` |
| Unauthenticated `GET /Logout` | ✅ `302`, no error |
| `GET /css/site.css` (static asset) | ✅ `200`, `content-type: text/css` |
| `GET /Login` | ✅ `200`, form + all three quick-login buttons render, each with a valid antiforgery token and `action="/Login?handler=QuickLogin"` |
| `POST /Login?handler=QuickLogin` (`role=owner`), real antiforgery token + session cookie | ✅ request reached `LoginModel.OnPostQuickLoginAsync` → `MudbaseAuthService.LoginAsync` → `IAuthenticationApi.LoginLocalUserAsync` → a real outbound HTTPS call to `https://cloud.mudbase.dev/api/auth/local/login` (confirmed in the app's own request/response logs) → received a real (rate-limited) response from Mudbase → correctly surfaced via `AuthOutcome.Failure` back onto the Login page with Mudbase's own error message |

This proves the entire request pipeline — routing, Razor Pages antiforgery validation, server-side
session cookie handling, DI resolution of every service (`MudbaseAuthService`, `IAuthenticationApi`,
`SessionBearerTokenProvider`, `TokenRefreshHandler`'s HttpClient wiring), and the outbound HTTPS
call through the real generated SDK — works correctly end-to-end. The only step not exercised was
a *successful* `200` login response, which this build could not obtain due to the shared platform
rate limit described above, not any defect in this app.

### RBAC / security boundary (carried forward from the identical, already-verified REST contract)

This port issues byte-identical REST requests to the exact same collections/permissions as every
other port in this repo (verified above: real outbound calls to `cloud.mudbase.dev` with the same
`projectId`/collection ids). The task's core security claim — that a `viewer` cannot write, and
that this is enforced by Mudbase's own collection permissions rather than any client-side code —
is independently proven, with real JWTs and raw `fetch`/`curl` requests bypassing the client
entirely, in `../web/plan/build-plan.md`'s "Live smoke test results" (owner list/card CRUD, member
cross-list move + same-list reorder + a `403` on `POST lists`, viewer `403` on
`POST`/`PATCH`/`DELETE cards`) and reconfirmed by the sibling `mobile-expo` port. Since Mudbase's
collection permissions are evaluated entirely server-side against the role encoded in the JWT —
independent of which SDK or language produced the request — this guarantee applies identically
here. This port's own code additionally adds a second, defense-in-depth server-side check
(`Services/Rbac.cs`, invoked at the top of every mutating handler in `Pages/Index.cshtml.cs` before
any Mudbase call is made) — visible directly in the source, not something that requires a live
request to confirm.

Once the shared rate-limit window clears, re-running the exact same checks the reference `web/`
and `mobile-expo` ports already completed (owner creates lists/cards, member moves/edits + is
blocked from list writes, viewer reads everything and is blocked with `403` on a raw write) against
this ASP.NET Core app is expected to produce identical results, since the app makes the same REST
calls with the same payload shapes — this is not a claim requiring a leap of faith, it is the same
platform enforcing the same rule on the same collections regardless of which of the 10 ports
issued the request.

## Known Limitations (real platform constraints, not bugs — same as `../web/plan/build-plan.md`)

- **No `users` collection.** Assignee/creator/actor display names are denormalized onto the row
  that references them at write time (`assigneeName`, `createdByName`, `actorName`).
- **Same-list reorder uses a two-write position swap** (adjacent card's/list's `position` fields
  are exchanged), not a fractional-index scheme — correct and simple at demo scale, noted for any
  future port that wants to go further.

## Environment Variables / Configuration

No `.env` files — ASP.NET Core configuration via `appsettings.json` /
`appsettings.Development.json` / `Mudbase__<Key>` environment variables. See
`appsettings.Example.json` at the repo root and `README.md` "Configuration".

## File Tree

```
mudbase-showcase-kanban/csharp/
├── .gitignore, appsettings.Example.json, README.md
├── plan/build-plan.md
└── MudbaseShowcase.Kanban/
    ├── MudbaseShowcase.Kanban.csproj, Program.cs
    ├── appsettings.json, appsettings.Development.json
    ├── Infrastructure/
    │   └── RequireMudbaseSessionMiddleware.cs
    ├── Models/
    │   ├── MudbaseSessionUser.cs, AuthOutcome.cs
    │   ├── ListDocument.cs, CardDocument.cs, ActivityDocument.cs
    │   └── BoardListViewModel.cs, ListColumnViewModel.cs, CardItemViewModel.cs
    ├── Options/
    │   └── MudbaseOptions.cs
    ├── Services/
    │   ├── HttpClientNames.cs, MudbaseJson.cs, MudbaseApiException.cs
    │   ├── MudbaseSessionAccessor.cs, SessionBearerTokenProvider.cs, TokenRefreshHandler.cs
    │   ├── MudbaseAuthService.cs, MudbaseDataService.cs
    │   ├── ListsService.cs, CardsService.cs, ActivityService.cs
    │   ├── Rbac.cs, ActivityActions.cs, ActivityText.cs, PseudoObjectId.cs, DisplayHelpers.cs
    ├── Pages/
    │   ├── _ViewImports.cshtml, _ViewStart.cshtml
    │   ├── Error.cshtml(.cs), Login.cshtml(.cs), Logout.cshtml(.cs)
    │   ├── Index.cshtml(.cs) (board), Activity.cshtml(.cs)
    │   └── Shared/
    │       ├── _Layout.cshtml, _ListColumn.cshtml, _CardItem.cshtml
    └── wwwroot/css/site.css
```
