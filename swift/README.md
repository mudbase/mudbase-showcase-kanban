# Mudbase Showcase — Kanban (SwiftUI / iOS)

A production-shaped SwiftUI iOS team task board (Kanban) built **entirely on top of
[Mudbase](https://www.mudbase.dev)** — zero custom backend — reimplementing the same reference
app as the companion Next.js app in `../web/`: same three collections (`lists`, `cards`,
`activity`), same three-role RBAC model (`owner`/`member`/`viewer`), same auth flow. Auth, the
board, and the activity feed all talk directly to `cloud.mudbase.dev` through the real generated
Mudbase Swift SDK.

## Why SPM, not an `.xcodeproj`

This package is deliberately `.xcodeproj`-free — same rationale as the sibling
`../../mudbase-showcase-social/swift` and `../../mudbase-showcase-ecommerce/swift` ports. Since
Xcode 14, you can open a `Package.swift` directly and run an `executableTarget` that defines a
SwiftUI `App` (`@main`) as a real iOS app on a Simulator or device — Xcode synthesizes the
Info.plist/bundle at build time, no project file needed. `swift build` from the CLI also succeeds
on plain macOS — the `platforms` list in `Package.swift` includes `.macOS(.v14)` purely so this
can be verified without Xcode.

## Setup

1. **Clone the SDK as a sibling directory.** From the same parent directory that contains this
   monorepo (`mudbase-showcase-kanban/`):
   ```bash
   git clone https://github.com/mudbase/mudbase-sdk.git
   ```
   You should end up with:
   ```
   parent/
     mudbase-showcase-kanban/
       swift/            <- this package (Package.swift lives here)
       web/
       ...
     mudbase-sdk/
       swift/            <- the SDK package Package.swift references
       ...
   ```

2. **The SwiftPM identity-collision workaround symlink is already committed.** This app's own SPM
   package directory is named `swift` and the SDK's own Swift subdirectory is *also* named
   `swift`. SwiftPM computes a local path dependency's package "identity" from the last path
   component of the path you give it, with no way to override that — so a plain
   `.package(path: "../../mudbase-sdk/swift")` would give this app's own package and its SDK
   dependency the *same* identity ("swift"), and dependency resolution would silently conflate
   them. `mudbase-showcase-kanban/mudbase-sdk-swift` is a relative symlink
   (`-> ../mudbase-sdk/swift`) that already exists at this monorepo's root for exactly this reason
   — the same workaround the ecommerce/social Swift ports established first. `Package.swift`
   references `../mudbase-sdk-swift`, not `../../mudbase-sdk/swift`.

3. **Configure.** Copy `Config.example.plist` to `Config.plist` (same directory) — it already has
   this showcase's real, already-provisioned project/collection/board IDs filled in, so no values
   need to be looked up:
   ```bash
   cp Config.example.plist Config.plist
   ```
   | Key | Value |
   |---|---|
   | `MudbaseProjectId` | `6a6d29b2d07caabbbdfc3f8c` |
   | `MudbaseBaseURL` | `https://cloud.mudbase.dev` (default, rarely needs changing) |
   | `ListsCollectionId` | `6a6d29cad07caabbbdfc3f9a` |
   | `CardsCollectionId` | `6a6d29cad07caabbbdfc3fad` |
   | `ActivityCollectionId` | `6a6d29cbd07caabbbdfc3fc6` |
   | `BoardId` | `6a6d4072d07caabbbdfc5d3c` |

   None of these are secrets — a project/collection/board id isn't sensitive (same rationale as
   `../web/.env.example`). `Config.plist` is still gitignored to keep this out of history as a
   matter of convention; there is no API key or other server-only credential in this app at all.
   `AppConfig.load` also reads `MUDBASE_PROJECT_ID` / `MUDBASE_LISTS_COLLECTION_ID` / etc.
   environment variables as a fallback, convenient for `swift run` during development; if neither
   source resolves every required key, the app renders a "Configuration required" screen instead of
   crashing (see `ConfigurationRequiredView.swift`).

4. **Open and run.**
   ```bash
   open Package.swift
   ```
   In Xcode: pick an iOS Simulator (or a physical device) as the run destination from the scheme
   selector, then Run. If you add `Config.plist` to the project navigator, make sure it's added to
   the `MudbaseShowcaseKanban` target's "Copy Bundle Resources" build phase (Xcode does this
   automatically when you drag the file in with "Add to target" checked).

## What's implemented

- **Auth** — email/password sign-in for all three roles (`owner`/`member`/`viewer`), with three
  "Quick sign in" buttons on the login screen for fast demoing. **No anonymous/guest session** —
  every role must sign in for real, since every one of Mudbase's own collection permissions on this
  project requires authentication (see `plan/build-plan.md` "Auth Model"). Session bootstrap from
  Keychain on launch, sign-out. Token pair stored in the Keychain via
  `Support/KeychainTokenStore.swift` — never `UserDefaults`. A 401 from an expired access token is
  transparently refreshed and retried once, for *every* authenticated call in the app — see
  `Networking/AccessTokenCoordinator.swift`.
- **Board** — a horizontally-scrolling row of list columns, each with its cards; owner-only
  add/rename/delete/reorder-left-right list controls; owner/member card create/edit/delete; card
  movement via "move up"/"move down" buttons and a "Move to…" menu (button/menu-based, not
  drag-and-drop — see `plan/build-plan.md` "Stack Decisions" for why); a read-only banner for the
  `viewer` role.
- **Activity feed** — full reverse-chronological log of every create/move/delete, rendered as plain
  sentences (`Support/ActivityText.swift`), pull-to-refresh, polling every 5 seconds while on
  screen.
- **Role-aware UI, server-enforced** — every role check in `Support/RBAC.swift` is UX gating (hide
  controls a role can't use, show a clear read-only notice); Mudbase's own collection permissions
  are the real enforcement boundary — verified live (see "Live verification" below), including
  calling the service layer directly to confirm a `member`/`viewer` write attempt 403s regardless of
  what the UI exposes.

## RBAC matrix

| Action | owner | member | viewer |
|---|---|---|---|
| Read lists / cards / activity | ✅ | ✅ | ✅ |
| Create / rename / delete / reorder lists | ✅ | ❌ | ❌ |
| Create / edit / delete / move cards | ✅ | ✅ | ❌ |

## Architecture

```
Sources/MudbaseShowcaseKanban/
  App/            @main entry point
  Config/         AppConfig (Config.plist + env var loader)
  Support/        Keychain, API error mapping, platform shims, RBAC helpers, pseudoObjectId /
                  relative-time / initials formatting, activity-feed sentence rendering
  Networking/     Thin wrappers over the generated SDK's async calls (auth, generic collection CRUD)
  Models/         MudbaseDocument, AppUser, BoardList, BoardCard, ActivityEntry
  Services/       SessionStore, ListsService, CardsService, ActivityService
  ViewModels/     LoginViewModel, BoardViewModel, ActivityViewModel
  Views/          SwiftUI views, grouped by feature area
```

`SessionStore` is the one app-wide store (created once in the `App` struct and injected via
`.environmentObject`); `BoardViewModel`/`ActivityViewModel` are each constructed explicitly by
their owning view (passed `config` and, for the board, the current user) rather than reached for
via `@EnvironmentObject`, so each screen's real dependencies stay visible at its call site — same
convention the sibling Swift ports use.

## The Mudbase Swift SDK, exactly as generated

Every Mudbase call in this app goes through the real generated `MudbaseSDK` async/await methods —
none of the signatures were guessed; each was read from
`../mudbase-sdk/swift/Sources/MudbaseSDK/APIs/*.swift` before being used:

- `AuthenticationAPI.loginLocalUser`, `.getLocalSession`, `.refreshToken`, `.logoutLocalUser`
- `DataAPI.listData` / `.getData` / `.createData` / `.updateData` / `.deleteData`

`AuthGateway.currentUser()` reads `AuthenticationAPI.getLocalSession(projectId:)` rather than
`getCurrentSession()` (no `projectId` parameter, only org-level roles) — deliberately, since
`getLocalSession` is the call that actually round-trips this project's Multi-Role `customRole`
(`owner`/`member`/`viewer`). Same choice the sibling Swift ports made, confirmed by reading both
API implementations side by side rather than assumed.

## Realtime

`../web/`'s `useBoardLive` subscribes to the `lists`/`cards`/`activity` collections' Socket.IO
rooms for live updates. There is no official Mudbase realtime client outside JavaScript, and the
sibling Swift ports already established the precedent of substituting periodic polling rather than
vendoring an unofficial, unaudited Socket.IO Swift library as a new SwiftPM dependency.
`BoardViewModel`/`ActivityViewModel` each re-fetch every 5 seconds via a structured
`Task { while !Task.isCancelled { ... } }` loop, started in `.task` and cancelled in
`.onDisappear`.

## Verification

There is no iOS Simulator in this build environment, so verification is a headless Swift Testing
suite (`Tests/ManualLiveFlowTests/ManualLiveFlowTests.swift`) that exercises this app's own
`Services`/`Networking` layer — the exact types the SwiftUI views and view models call — directly
against the real, live `cloud.mudbase.dev` project, the same approach the sibling Swift ports use.
It's disabled by default (a plain `swift test` never makes network calls or writes real documents);
run it explicitly with:

```bash
RUN_LIVE_FLOW_TEST=1 swift test --filter ManualLiveFlowTests
```

It signs in as all three demo accounts (`kanban.owner.demo@gmail.com` /
`kanban.member.demo@gmail.com` / `kanban.viewer.demo@gmail.com`, password `KanbanTest123!`), has
the owner create a card, the member move it to a different list and clear its assignee, confirms a
member can't create a list and a viewer can't create/update/delete a card (both `403`, called
directly at the service layer — not just a hidden UI button), forces a 401 to confirm the
refresh-and-retry policy actually recovers a call, and cleans up its own test card.

**Result:** `Test fullKanbanFlow() passed after 12.574 seconds` — zero failures against the real,
live project. Full step-by-step results, and a real (non-bug) finding along the way — the shared
per-IP login rate limit was tightly contended during this build's verification window, worked
around with pre-minted per-account tokens via `OWNER_ACCESS_TOKEN`/`MEMBER_ACCESS_TOKEN`/
`VIEWER_ACCESS_TOKEN` (+ `_REFRESH_TOKEN`) environment variables — are in `plan/build-plan.md`
"Live verification results".

```bash
RUN_LIVE_FLOW_TEST=1 \
OWNER_ACCESS_TOKEN=... OWNER_REFRESH_TOKEN=... \
MEMBER_ACCESS_TOKEN=... MEMBER_REFRESH_TOKEN=... \
VIEWER_ACCESS_TOKEN=... VIEWER_REFRESH_TOKEN=... \
swift test --filter ManualLiveFlowTests
```

## Known limitations (real platform/SDK constraints, not bugs)

See `plan/build-plan.md` → "Known Limitations" — no `users` collection (names are denormalized at
write time), same-list reorder uses a simple two-write position swap rather than a
fractional-index scheme (fine at demo scale), certificate pinning/biometric auth are out of scope
(a focused reimplementation, not a production hardening pass), and the shared per-IP login rate
limit documented above.

## Design choice: button/menu card movement, not drag-and-drop

Cards move via an accessible "move up" / "move down" pair and a "Move to…" menu, not a pointer-drag
gesture. This ports the reference web app's own deliberate choice — see `plan/build-plan.md` →
"Stack Decisions" for the full rationale.
