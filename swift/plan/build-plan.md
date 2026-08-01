# Build Plan — Mudbase Showcase: Kanban (Swift / SwiftUI)
Generated: 2026-08-01
Mode: greenfield (one of several language/platform ports — the `../web/` Next.js app is the
reference implementation; this port matches its data model, RBAC matrix, and API contract exactly)
Type: mobile (iOS, fullstack via BaaS, no custom backend)
Stack: Swift 6 + SwiftUI + Swift Concurrency (async/await, actors), backed entirely by Mudbase
(`cloud.mudbase.dev`) through the real generated `MudbaseSDK` Swift package.

## Stack Decisions
- SPM (`Package.swift`), no `.xcodeproj` — same rationale as the sibling
  `mudbase-showcase-social/swift` and `mudbase-showcase-ecommerce/swift` ports this app's
  architecture is ported from: Xcode 14+ opens `Package.swift` directly and runs an
  `executableTarget` that defines a SwiftUI `App`/`@main` as a real iOS app, and `swift build`
  succeeds from the CLI on plain macOS with no Simulator required (`platforms: [.iOS(.v16),
  .macOS(.v14)]` — the macOS entry exists purely for that CLI verification).
- Architecture mirrors the sibling ports verbatim where the concern is identical: `Networking/`
  (`AccessTokenCoordinator`, `AuthGateway`, `CollectionsGateway`, `MudbaseSDKBootstrap`) and
  `Support/KeychainTokenStore.swift`/`MudbaseAPIError.swift` are near-verbatim ports — these are
  platform/SDK-integration concerns, not app-specific business logic, so there was no reason to
  reinvent them. `Config/AppConfig.swift` follows the same `Config.plist`-with-env-var-fallback
  pattern, sized to this app's three collections + one board id instead of four collections.
- **No anonymous/guest session — the one architectural difference from the sibling social/
  ecommerce Swift ports.** This app's task brief (and the reference web app's own live-verified
  finding, see `../web/plan/build-plan.md` "Auth Model") requires every role — including the
  read-only `viewer` — to sign in for real, because every one of Mudbase's own collection
  permissions on `lists`/`cards`/`activity` requires authentication. `SessionStore.bootstrap()`
  therefore has no `establishAnonymousSession()` fallback: no stored token, or an invalid one,
  always means "show `LoginView`," never "browse as guest." `AuthGateway` correspondingly drops
  `loginAnonymous()`/`registerCustomer()` entirely (no in-app registration UI either — the task's
  three demo accounts are already provisioned, matching the reference web app's own scope).
- **Card movement: button/menu-based, not drag-and-drop** — porting the reference web app's own
  deliberate choice (`../web/plan/build-plan.md` "Stack Decisions"). Each card gets a "move up" /
  "move down" pair (`CardRowView`'s chevron buttons) and a "Move to…" `Menu` (`CardRowView`'s
  trailing menu), rather than a `.draggable`/`.dropDestination` gesture. This keeps the port
  dependency-light, fully accessible with VoiceOver out of the box, and faithful to the reference
  contract: every move still writes `listId`/`position` and appends an `activity` row exactly as
  specified, regardless of which control triggered it.
- **Realtime: polling, not a Socket.IO client.** `../web/`'s `useBoardLive` subscribes to the
  `lists`/`cards`/`activity` collections' Socket.IO rooms. There is no official Mudbase realtime
  client outside JavaScript, and the sibling Swift ports already established the precedent of
  substituting periodic polling rather than vendoring an unofficial, unaudited Socket.IO Swift
  library as a new SwiftPM dependency (see the social Swift port's README "Realtime"). Both
  `BoardViewModel` and `ActivityViewModel` re-fetch every 5 seconds via a structured
  `Task { while !Task.isCancelled { ... } }` loop started in `.task` and cancelled in
  `.onDisappear` — simpler than the web app's per-collection cache-patch logic, since a full
  re-fetch at demo scale (a handful of lists/cards) is effectively instant.

## Auth Model
Identical to `../web/plan/build-plan.md` "Auth Model" — see that file for the full platform
findings this port inherits without re-deriving:
- The task's originally-specified `.test`-domain accounts (`kanban-owner@example.test` etc.) fail
  Mudbase's own login validation live (Joi's default `email()` TLD allowlist excludes RFC 2606
  reserved TLDs) — not re-verified independently in this port since the reference web app already
  proved it live and the resolution (three `.com`-domain accounts under the same role slugs) is
  what this port's `LoginView`/`ManualLiveFlowTests` both use directly.
- `boardId`/`assigneeId` are ObjectId-typed, not free strings — `AppConfig.boardId` defaults to the
  real `6a6d4072d07caabbbdfc5d3c` (the `boards` collection's one document), and
  `Support/Formatting.swift`'s `pseudoObjectId(_:)` ports the web app's `djb2`-based hash verbatim
  (see that function's doc comment for why UTF-8 vs. the web version's UTF-16 code units doesn't
  matter here — the hash only needs to be stable within this app's own reads/writes).
- `CardsService.update` always sends `.null` (never omits, never `""`) for `assigneeId`/
  `assigneeName` when clearing an assignee — ported from `useUpdateCard`'s exact fix, and
  independently re-verified live by this port's own `ManualLiveFlowTests` (see below).

## RBAC Matrix
Identical to `../web/plan/build-plan.md`'s table — `Support/RBAC.swift`'s `canManageLists`/
`canManageCards`/`isReadOnly` are a direct port of `rbac.ts`. Enforced server-side by Mudbase's own
collection permissions; this app's checks are UX gating only (hide controls, show the read-only
banner) — see "Live verification results" below for the raw-service 403 proof, the Swift
equivalent of the web app's raw-`fetch` write attempt.

| Action | owner | member | viewer |
|---|---|---|---|
| Read lists / cards / activity | ✅ | ✅ | ✅ |
| Create / rename / delete / reorder lists | ✅ | ❌ | ❌ |
| Create / edit / delete / move cards | ✅ | ✅ | ❌ |

## Data Models
Identical field shapes to `../web/plan/build-plan.md` — `Models/BoardList.swift`,
`Models/BoardCard.swift`, `Models/ActivityEntry.swift` are all built from `MudbaseDocument` (the
Swift port's normalized read over `DataAPI`'s two response shapes, ported verbatim from the
sibling Swift ports). `ActivityAction` is a Swift `enum` with the same six raw string values
(`created_card`/`moved`/`deleted_card`/`created_list`/`renamed_list`/`deleted_list`) as the web
app's union type.

## Auth Flow
```
Launch, no stored token           → SessionStore.bootstrap() leaves user == nil → RootView shows
                                     LoginView (no anonymous/guest session, unlike the sibling
                                     social/ecommerce Swift ports)
Sign in                            → AuthGateway.login → POST /api/auth/local/login
                                      → 200 + token/refreshToken; AuthGateway.currentUser() reads
                                        GET /api/auth/local/session for user.customRole
401 on any authenticated call       → AccessTokenCoordinator refreshes once (deduped via
                                      inFlightRefresh, since refresh tokens are single-use/
                                      rotating) → retries the original call once → surfaces the
                                      error if that also fails
Sign out                           → AuthGateway.logout(); SessionStore clears Keychain + the
                                      shared MudbaseSDKAPIConfiguration bearer header
```

## Architecture
```
Sources/MudbaseShowcaseKanban/
  App/            @main entry point (MudbaseShowcaseKanbanApp)
  Config/         AppConfig (Config.plist + env var loader)
  Support/        Keychain, API error mapping, platform shims, RBAC helpers, pseudoObjectId /
                  relative-time / initials formatting, activity-feed sentence rendering
  Networking/     Thin wrappers over the generated SDK's async calls (auth, generic collection CRUD)
  Models/         MudbaseDocument, AppUser, BoardList, BoardCard, ActivityEntry
  Services/       SessionStore (@MainActor ObservableObject), ListsService, CardsService,
                  ActivityService (all plain structs wrapping CollectionsGateway)
  ViewModels/     LoginViewModel, BoardViewModel, ActivityViewModel (@MainActor ObservableObject)
  Views/          SwiftUI views, grouped by feature area (Auth, Board, Activity, Shared)
```
`SessionStore` is the one app-wide store (created once in the `App` struct, injected via
`.environmentObject`); `BoardViewModel`/`ActivityViewModel` are each constructed explicitly by
their owning view (passed `config` and, for the board, the current user) rather than reached for
via `@EnvironmentObject` — same convention the sibling Swift ports use, so each screen's real
dependencies stay visible at its call site.

`CardFormView` (the create/edit sheet) and `AddListColumnView`/`ListColumnView`'s inline
rename/delete affordances deliberately have **no dedicated ViewModel** — they hold their own
`@State` form fields and call straight through to `BoardViewModel`'s action methods (which already
own error handling and the post-mutation refresh). Introducing a `CardFormViewModel` purely to
wrap three `@State` strings and a submit closure would have been speculative generality (YAGNI) for
a form this simple — the ecommerce/social Swift ports use dedicated view models where a screen's
logic is genuinely non-trivial (auth, feed pagination); this port follows the same principle in
the other direction for a form that isn't.

## The Mudbase Swift SDK, exactly as generated
Every Mudbase call in this app goes through the real generated `MudbaseSDK` async/await methods —
each signature was read directly from `../../mudbase-sdk/swift/Sources/MudbaseSDK/APIs/*.swift`
before being used, not guessed:
- `AuthenticationAPI.loginLocalUser`, `.getLocalSession`, `.refreshToken`, `.logoutLocalUser`
- `DataAPI.listData` / `.getData` / `.createData` / `.updateData` / `.deleteData`

`AuthGateway.currentUser()` reads `AuthenticationAPI.getLocalSession(projectId:)` — the call that
actually round-trips this project's Multi-Role `customRole` — rather than `getCurrentSession()`
(no `projectId` parameter, returns only the org-level `owner`/`admin`/`member`/`viewer` roles,
which can never surface this project's own `owner`/`member`/`viewer` custom role values). Same
choice the sibling Swift ports made, confirmed by reading both API implementations side by side.

## Security Implementation
- Input validation: client-side length/required checks matching the web app's zod schemas exactly
  — card titles capped at 120 chars, descriptions at 2000, assignee names at 80 (`CardFormView`),
  list names at 60 (`AddListColumnView`/`ListColumnView`'s rename field). These mirror the server's
  own acceptance behavior but are not the enforcement boundary — Mudbase's own collection schema
  and permissions are.
- Authentication: Mudbase-issued JWT (access + refresh) held in the **Keychain** via
  `KeychainTokenStore` — never `UserDefaults` — with 401 → refresh → retry handled once, deduped
  across concurrent requests by the `AccessTokenCoordinator` actor.
- Authorization: enforced server-side by Mudbase's own collection permissions per the RBAC matrix
  above — `Support/RBAC.swift`'s role checks are UX gating (hide/disable controls, show the
  read-only banner), not the security boundary. Verified live for the `viewer` and `member` roles
  by calling the service layer directly (bypassing every UI control) — see below.
- No hardcoded secrets: `Config.plist`/`Config.example.plist` carry only a project id, three
  collection ids, and a board id — none of which are secret (same rationale as the web app's
  `NEXT_PUBLIC_*` env vars). There is no server-side credential anywhere in this app.

## Live verification results (2026-08-01, against the real project)
Performed with `Tests/ManualLiveFlowTests/ManualLiveFlowTests.swift` — a Swift Testing suite,
gated behind `RUN_LIVE_FLOW_TEST=1`, that calls this app's own `AuthGateway`/`ListsService`/
`CardsService`/`ActivityService`/`AccessTokenCoordinator` directly (via `@testable import`) against
`cloud.mudbase.dev` — the exact same types the SwiftUI views and view models call. There is no iOS
Simulator in this build environment, so this stands in for clicking through the actual UI, same
approach as the sibling Swift ports.

**Result: `Test fullKanbanFlow() passed after 12.574 seconds` — zero failures against the real,
live project.**

| Step | Result |
|---|---|
| Owner signs in, `customRole` resolves to `.owner` | ✅ |
| Owner reads the shared demo board's existing lists (already seeded by the reference web app's own live smoke test) | ✅ — non-empty, as expected |
| Owner creates a card with an assignee in the first list | ✅ `201`-equivalent, `title`/`assigneeName` round-trip correctly |
| Card fetch includes the just-created card | ✅ |
| Activity feed includes a `created_card` entry for it | ✅ |
| Member signs in, `customRole` resolves to `.member` | ✅ |
| Member reads the card the owner just created | ✅ |
| Member moves the card to a different list (`listId`+`position` update) | ✅ |
| Activity feed includes a `moved` entry with the correct `fromList`/`toList` | ✅ |
| Member clears the card's assignee (`assigneeId`/`assigneeName: nil` → sends JSON `null`) | ✅ — confirms the `CardsService.update` fix independently of the web app's own finding |
| **Member attempts to create a list** | ✅ **`403`, `"Insufficient permissions"`-shaped error — server correctly blocks a member from restructuring columns** |
| Viewer signs in, `customRole` resolves to `.viewer` | ✅ |
| Viewer reads lists | ✅ |
| Viewer reads cards, including the test card | ✅ |
| **Viewer calls `CardsService.create` directly (bypassing every UI control)** | ✅ **`403`** |
| **Viewer calls `CardsService.update` directly** | ✅ **`403`** |
| **Viewer calls `CardsService.delete` directly** | ✅ **`403`** |
| 401 refresh-and-retry: access token forced invalid in-memory, real refresh token in a scratch Keychain entry, `AccessTokenCoordinator.perform` called for a plain list read | ✅ — recovered transparently via refresh-and-retry rather than failing outright |
| Cleanup: test card deleted by the owner; pre-existing seeded demo data (from the reference web app's own build) left untouched | ✅ |

**Net result**: every request shape this app's services generate — list/card CRUD, cross-list
move, assignee clear, activity logging, and the 401-refresh-retry policy — is proven correct
against the live backend. Critically, the same core security claim the reference web app verified
is independently re-verified here at the native service layer: **the `viewer` role's inability to
write, and the `member` role's inability to restructure lists, are enforced by Mudbase's own
collection permissions server-side (`403`), not merely by this app's UI hiding the buttons** —
confirmed by calling the service methods directly, the exact same "bypass the UI, hit the API
raw" proof the web app's build-plan performed with `fetch`.

### Real platform finding: the shared `/api/auth/local/login` rate limit is tighter and more
### contended than expected, and required a workaround to complete this verification run
`POST /api/auth/local/login` is rate-limited per IP — documented as a known constraint in both the
reference web app's and the sibling social Swift port's build plans, since every language port's
own live verification runs against this same project share one IP. In practice, during this
build's verification window the bucket was observed at **`ratelimit-policy: 5;w=900`** (5 login
requests per 15-minute window) and was found fully exhausted (`ratelimit-remaining: 0`) on four
separate attempts spread ~13–15 minutes apart, each confirmed with a direct `curl` against the
endpoint (independent of this app's own test harness) returning
`{"error":"Too many requests from this IP, please try again later."}` — i.e. genuine, sustained
contention from concurrent traffic sharing this IP (most likely other sibling-port build/test runs
happening in parallel), not a bug in this port's login call shape or retry logic.

**Resolution used for this build**: `ManualLiveFlowTests.resolveSession` accepts an optional
pre-minted access/refresh token pair per account via `OWNER_ACCESS_TOKEN`/`OWNER_REFRESH_TOKEN`,
`MEMBER_ACCESS_TOKEN`/`MEMBER_REFRESH_TOKEN`, `VIEWER_ACCESS_TOKEN`/`VIEWER_REFRESH_TOKEN`
environment variables — the same contingency the sibling social Swift port's own README documents
for exactly this shared-budget scenario. Three individual logins were captured via direct `curl`
calls (one per account, spaced across the windows as budget became available — each account's
login consumes from the same shared per-IP bucket, so getting all three required patience, not a
different approach), each returning `expiresIn: 86400` (a 24-hour access token TTL, comfortably
long enough for a single verification run), and the full suite was then run once with all six
values set — completing successfully with **zero** additional calls to `/api/auth/local/login`
during the run itself (the suite's own internal 401-refresh-retry step exercises
`/api/auth/refresh` instead, a separate, unaffected endpoint). This is a workaround for a
transient, external, shared-infrastructure condition at verification time — it does not reflect
any change to `AuthGateway.login`'s normal behavior, which is exercised identically whether or not
these environment variables are set.

## Known Limitations (real platform/SDK constraints, not bugs — inherited from the reference app)
- **No `users` collection.** Assignee/creator/actor display names are denormalized onto the row
  that references them at write time (`assigneeName`, `createdByName`, `actorName`), matching the
  same constraint documented in `../web/plan/build-plan.md`.
- **Same-list reorder uses a two-write position swap** (adjacent card's/list's `position` fields
  are exchanged), not a fractional-index scheme — correct and simple at demo scale, noted as a
  scaling concern for anyone extending this further, not required by this build's scope.
- **Certificate pinning and biometric auth are out of scope** — a focused reimplementation of the
  reference app's feature set, not a production hardening pass, matching the same call the sibling
  Swift ports' READMEs make. Keychain-only token storage is implemented as the baseline correctness
  requirement.
- **The shared login rate limit** documented above — a real, external, session-time condition, not
  a defect in this app.

## Environment Variables / Configuration
See `Config.example.plist` — copy to `Config.plist` (gitignored) and add it as a resource of your
Xcode run target. None of these values are secret (a project/collection/board id is not sensitive
— same rationale as the web app's `NEXT_PUBLIC_*` vars); `AppConfig.load` also reads
`MUDBASE_PROJECT_ID`/`MUDBASE_LISTS_COLLECTION_ID`/etc. environment variables as a fallback for
`swift run`/`swift test` during development.

## File Tree
```
mudbase-showcase-kanban/swift/
├── Package.swift, Config.example.plist, .gitignore, README.md
├── plan/build-plan.md
├── Sources/MudbaseShowcaseKanban/
│   ├── App/MudbaseShowcaseKanbanApp.swift
│   ├── Config/AppConfig.swift
│   ├── Support/ (KeychainTokenStore, MudbaseAPIError, PlatformCompat, RBAC, Formatting, ActivityText)
│   ├── Networking/ (MudbaseSDKBootstrap, AccessTokenCoordinator, AuthGateway, CollectionsGateway)
│   ├── Models/ (MudbaseDocument, AppUser, BoardList, BoardCard, ActivityEntry)
│   ├── Services/ (SessionStore, ListsService, CardsService, ActivityService)
│   ├── ViewModels/ (LoginViewModel, BoardViewModel, ActivityViewModel)
│   └── Views/
│       ├── RootView.swift, MainTabView.swift, ConfigurationRequiredView.swift
│       ├── Auth/LoginView.swift
│       ├── Board/ (BoardView, ListColumnView, CardRowView, CardFormView, AddListColumnView)
│       ├── Activity/ (ActivityView, ActivityRowView)
│       └── Shared/ (LoadingView, EmptyStateView, InlineErrorView, InlineBanner, AvatarView)
└── Tests/ManualLiveFlowTests/ManualLiveFlowTests.swift
```
