# Mudbase Showcase — Kanban (C# / ASP.NET Core)

A realtime-data team task board (Kanban), server-rendered with **ASP.NET Core 10 Razor Pages**,
built **entirely on [Mudbase](https://www.mudbase.dev)** — auth, database, and role-based access
control — with **zero custom backend**. This is the C# port of the reference implementation in
`../web/` (Next.js): same data model, same API contract, same RBAC matrix, against the same live
project (see `plan/build-plan.md` → "Live smoke test results" for exactly what this build verified
live end-to-end versus what carries forward from the reference app's identical, already-completed
RBAC proof — this build hit the shared demo project's login rate limit).

## Stack

ASP.NET Core 10, Razor Pages, the real [Mudbase C# SDK](https://github.com/mudbase/mudbase-sdk)
(generated client, `mudbase-sdk/csharp`), talking directly to `cloud.mudbase.dev`. There is no
database, no ORM, and no custom API of any kind in this app — every list/card/activity read or
write goes straight to Mudbase's REST API through the generated SDK, authenticated with the signed-in
user's own JWT (held server-side in ASP.NET Core session state, never exposed to client JS).

No client-side JS framework and no drag-and-drop library: cards move via accessible "move
up"/"move down" buttons and a "Move to..." `<select>`, matching the reference web app's own
explicit design choice (dependency-light, fully keyboard/screen-reader operable). Inline
rename/edit/add forms use native `<details>/<summary>` progressive disclosure — no bundler, no
build step, nothing beyond a `confirm()` dialog on destructive actions.

## What it demonstrates

| Feature | Mudbase capability | Where |
|---|---|---|
| Three-role auth (owner / member / viewer), no anonymous session | `POST /api/auth/local/login`, `GET /api/auth/session` | `Services/MudbaseAuthService.cs`, `Infrastructure/RequireMudbaseSessionMiddleware.cs` |
| Board columns (lists), owner-managed | Collection CRUD, `lists` | `Services/ListsService.cs`, `Pages/Shared/_ListColumn.cshtml` |
| Card CRUD (owner + member) | Collection CRUD, `cards` | `Services/CardsService.cs`, `Pages/Shared/_CardItem.cshtml` |
| Move card between lists / reorder in place | `PATCH` on `listId`/`position` + an `activity` row per move | `Services/CardsService.cs`, `Pages/Index.cshtml.cs`'s `OnPostMoveCardAsync`/`OnPostReorderCardAsync` |
| Reverse-chronological activity log | Collection read, `sort: "-createdAt"` | `Services/ActivityService.cs`, `Pages/Activity.cshtml(.cs)` |
| Role-aware UI, server-enforced | Mudbase's own per-role collection permissions | `Services/Rbac.cs`, every mutating handler in `Pages/Index.cshtml.cs` |
| Automatic token refresh | `POST /api/auth/refresh`, single-use rotating refresh tokens | `Services/TokenRefreshHandler.cs` (ported from `mudbase-showcase-social/csharp`) |

## RBAC matrix

| Action | owner | member | viewer |
|---|---|---|---|
| Read lists / cards / activity | ✅ | ✅ | ✅ |
| Create / rename / delete / reorder lists | ✅ | ❌ | ❌ |
| Create / edit / delete / move / reorder cards | ✅ | ✅ | ❌ |

The UI hides write controls a role cannot use, and every mutating Razor Page handler re-checks the
role server-side via `Services/Rbac.cs` before calling Mudbase at all. Neither of those is the real
enforcement boundary, though — Mudbase's own collection permissions are, verified live with a raw
request bypassing this app entirely (see `plan/build-plan.md` → "Live smoke test results").

## Getting started

This repo assumes a sibling clone of the Mudbase C# SDK (not published on NuGet):

```bash
cd ..                                             # parent directory of this repo
git clone https://github.com/mudbase/mudbase-sdk.git
cd mudbase-showcase-kanban/csharp/MudbaseShowcase.Kanban
dotnet run
```

Then open `http://localhost:5000` (or whatever port `dotnet run` reports). Sign in with one of the
three demo accounts via the login page's quick-fill buttons (or type credentials manually) — see
`plan/build-plan.md` for account details and RBAC verification notes.

> **.NET version note**: this project targets `net10.0`. If your machine only has an older SDK
> installed, either install the .NET 10 SDK or see `MudbaseShowcase.Kanban.csproj`'s comment for
> why an older `TargetFramework` builds but will not run without a matching runtime installed.

## Configuration

No `.env` files — configuration lives in `MudbaseShowcase.Kanban/appsettings.json` (already
pointed at the shared demo project; none of these values are secrets — a project/collection/board
id is not sensitive, see `plan/build-plan.md` → "Security Implementation") or the equivalent
`Mudbase__<Key>` environment variables for a different deployment. See
`appsettings.Example.json` at the repo root for the full key list with descriptions.

## Provisioning (what already exists on Mudbase, not in this repo)

This app expects a Mudbase project already set up with:

1. Local auth enabled with the Multi-Role feature, three role slugs: `owner`, `member`, `viewer`.
2. Three collections — `lists`, `cards`, `activity` — with the field shapes documented in
   `plan/build-plan.md`, and each role granted the permissions in the RBAC matrix above.
3. A `boards` collection with exactly one document (its id is `Mudbase:BoardId` in
   `appsettings.json`) — see `plan/build-plan.md` for why this must be a real ObjectId rather than
   an arbitrary slug.

## Live smoke test

See `plan/build-plan.md` → "Live smoke test results" for the full account. This build verified the
entire request pipeline end-to-end (routing, antiforgery, session, DI, the real outbound HTTPS call
through the generated SDK) live, but hit the shared demo project's login rate limit (all 10
language/platform ports in this repo share the same three accounts and source IP) before a fresh
`200` login could complete. The RBAC/security-boundary proof — that a `viewer`'s raw write attempt
is rejected server-side (`403`) by Mudbase's own collection permissions, not by this app's UI — is
carried forward from the reference `../web/` app's and the sibling `mobile-expo` port's identical,
already-completed live verification against this exact project/collections/roles.

## Known limitations (real platform constraints, not bugs)

See `plan/build-plan.md` → "Known Limitations" — no `users` collection (names are denormalized at
write time), and same-list reorder uses a simple two-write position swap rather than a
fractional-index scheme (fine at demo scale).

## Relationship to the other ports

This is one of several per-language/platform reimplementations of the same reference Kanban app
(see the repo root `README.md`). All ports share the same live Mudbase project, the same three
demo accounts, and the same data model — this port in particular mirrors
`mudbase-showcase-social/csharp`'s established ASP.NET Core project conventions (DI wiring,
`TokenRefreshHandler`, session-backed auth) rather than introducing new ones.
