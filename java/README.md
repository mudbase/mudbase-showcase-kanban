# Mudbase Showcase — Kanban (Java / Spring Boot edition)

A team task board (Kanban) built **entirely on [Mudbase](https://www.mudbase.dev)** — auth,
database, role-based access control, no custom backend of any kind — reimplemented in
**Spring Boot + Thymeleaf** (server-rendered, no client-side JS framework). This is a companion to
the reference Next.js app at `../web`: same Mudbase project, same three collections
(`lists`/`cards`/`activity`), same RBAC matrix and business rules; see `plan/build-plan.md` for
what deliberately differs (server-rendered forms instead of drag-and-drop or realtime, no
registration UI) and why.

## Stack

Java 17, Spring Boot 3.3 (Web MVC, not WebFlux), Thymeleaf, Bean Validation. The only outbound
HTTP this app makes is the real Mudbase Java SDK against `cloud.mudbase.dev` — no other services,
no database of its own.

## Setup

### 1. Install the Mudbase SDK to your local Maven repository (one-time, mandatory)

The SDK is **not published to Maven Central** — it lives at
[github.com/mudbase/mudbase-sdk](https://github.com/mudbase/mudbase-sdk), subdirectory `java/`.
Clone it as a **sibling** of this repo, then install it into `~/.m2`:

```bash
git clone https://github.com/mudbase/mudbase-sdk.git
cd mudbase-sdk/java && mvn install
```

This installs `dev.mudbase:mudbase-sdk:2.0.0` into your local repo — already done on any machine
that previously set up the sibling `mudbase-showcase-social/java` or
`mudbase-showcase-ecommerce/java` ports, since it's the exact same artifact.

### 2. Configure environment variables

```bash
cp .env.example .env
# fill in your provisioned project's IDs
set -a && source .env && set +a
```

See `.env.example` for the full list. You need a Mudbase project already provisioned with local
auth, the Multi-Role feature's three role slugs (`owner`/`member`/`viewer`), the three
collections (`lists`, `cards`, `activity`) shaped as documented in `../web/plan/build-plan.md`
with the RBAC matrix below, and a `boards` collection supplying a single real ObjectId board id —
this app assumes that provisioning already exists, exactly like the reference web app does.

### 3. Build and run

```bash
cd mudbase-showcase-kanban/java
mvn clean install   # verify it builds clean
mvn spring-boot:run
```

Visit `http://localhost:8080` and sign in with one of the three demo accounts (the login page
ships one-click "Sign in as Owner/Member/Viewer" buttons for fast demoing).

## What's implemented

| Page | Route | Notes |
|---|---|---|
| Board | `GET /` | Lists in column order, each list's cards in position order; auth-gated for every role, including `viewer` |
| Create list | `POST /lists` | Owner-only; name ≤60 chars |
| Rename list | `POST /lists/{id}/rename` | Owner-only |
| Delete list | `POST /lists/{id}/delete` | Owner-only; cascades to every card in the list |
| Reorder list | `POST /lists/{id}/move-left`, `POST /lists/{id}/move-right` | Owner-only; swaps `position` with the adjacent list, not logged to activity |
| Create card | `POST /cards` | Owner/member; title ≤120 chars, description ≤2000, optional free-typed assignee name |
| Edit card | `POST /cards/{id}/edit` | Owner/member; not logged to activity |
| Delete card | `POST /cards/{id}/delete` | Owner/member |
| Move card to another list | `POST /cards/{id}/move` | Owner/member; appends to the end of the target list |
| Reorder card in its list | `POST /cards/{id}/move-up`, `POST /cards/{id}/move-down` | Owner/member; swaps `position` with the adjacent card |
| Activity feed | `GET /activity` | Reverse-chronological, any signed-in role |
| Login / Logout | `GET/POST /login`, `POST /logout` | Email + password, plus three quick-fill demo buttons — no registration UI, see "Known limitations" |

Session/auth: the Mudbase-issued JWT is stored server-side in the Spring `HttpSession` — it is
never sent to the browser (pages are plain server-rendered HTML with a shared stylesheet, no
client JS at all beyond ordinary form submissions and native `<details>` disclosure widgets).

## RBAC matrix

| Action | owner | member | viewer |
|---|---|---|---|
| Read lists / cards / activity | ✅ | ✅ | ✅ |
| Create/rename/delete/reorder lists | ✅ | ❌ | ❌ |
| Create/edit/delete/move cards | ✅ | ✅ | ❌ |

Enforced **twice, independently**: this app's own `ListService`/`CardService` reject a
disallowed mutation with a 403 (`ForbiddenActionException`) before ever calling Mudbase, and
Mudbase's own collection permissions reject the exact same request again one layer further down
— verified live with a raw `curl` call using the `viewer` role's own JWT directly against
`cloud.mudbase.dev`, bypassing this app entirely. See `plan/build-plan.md` "Live smoke test
results" for the full detail. The Thymeleaf templates additionally hide every control a role
can't use — that's UX, not the security boundary.

## Architecture notes

- **`mudbase/`** wraps the generated SDK: `MudbaseDataClient` (thin `DataApi` wrapper with
  document-shape normalization, retry-once-on-401 via `SessionAuthService`), `MudbaseAuthClient`
  (login/refresh/logout, bypassing the generated SDK's login model for a known Gson strict-schema
  bug against this project's Multi-Role account shape), `MudbaseApiException`, `PageResult`,
  `DocumentMapper`. Ported near-verbatim from the sibling social/ecommerce Java showcases, since
  these are fixes for real bugs against the same live backend, not app-specific code.
- **`auth/`** — `AuthSession` (the signed-in identity, held in `HttpSession`) and
  `SessionAuthService`, including the already-fixed `recoverFromUnauthorized` token-mismatch
  recovery (see its javadoc for the full bug history — reused verbatim per the task's
  instruction, not rediscovered).
- **`domain/`** — `BoardList`, `BoardCard`, `ActivityEntry`: thin, immutable wrappers around a raw
  Mudbase document map, each with a `fromDocument(Map)` factory. `ActivityEntry#getDescription()`
  mirrors the reference web app's `describeActivity()` sentence-for-sentence.
- **`support/`** — `RoleSupport` (the RBAC matrix as code, mirrors `../web/src/lib/rbac.ts`),
  `ForbiddenActionException` (this app's own 403), `PseudoObjectId` (derives a stable,
  valid-looking ObjectId from a free-typed assignee name — same djb2 algorithm as the reference
  web app's `pseudoObjectId()`, so the same name maps to the same id in both apps),
  `RedirectSupport` (open-redirect guard for the `?redirect=` param), `Formatting`,
  `ViewModelHelper` (populates the header/role attributes every template needs).
- **`service/`** — one service per collection (`ListService`, `CardService`, `ActivityService`)
  plus `AuthService`. Every mutating method takes the acting `AuthSession` first and enforces
  `RoleSupport` before touching Mudbase — this is the real, independent server-side enforcement
  layer described above.
- **`web/`** — one controller per concern (`BoardController` for the read model,
  `ListController`/`CardController` for mutations, `ActivityController`, `AuthController`),
  `BoardViewAssembler` (turns raw lists/cards into per-column view models with precomputed
  prev/next neighbor ids so the template can disable edge buttons without inline logic),
  `GlobalExceptionHandler` (401 → session-expired redirect; 403 → error page;
  `ForbiddenActionException` → 403 error page; anything else → generic 500 page, no internals
  leaked), `AuthGateInterceptor` + `WebConfig` (every route except `/login` requires a signed-in
  session — there is no anonymous/guest browsing in this app at all, unlike the sibling social/
  ecommerce ports).

## Known limitations (real platform constraints or deliberate scope choices, not bugs)

- **No `users` collection.** Assignee/creator/actor display names are denormalized onto the row
  that references them at write time, matching the same constraint documented in every other
  showcase in this repo.
- **No realtime layer.** This is a classic server-rendered app: every mutation redirects back to
  `GET /`, which re-fetches lists/cards fresh. The reference web app's Socket.IO live updates have
  no equivalent here, by design (see `plan/build-plan.md` "Known differences").
- **No drag-and-drop** — the reference web app doesn't have it either (an explicit design choice
  documented in its own build plan, to stay dependency-light and keyboard/screen-reader
  operable). This port's up/down/left/right/"move to…" controls are the server-form equivalent
  of the same web app controls, not a simplification of a richer web experience.
- **No registration UI.** All three demo accounts are pre-provisioned; see `plan/build-plan.md`
  "Stack Decisions".
- **Same-list reorder uses a two-write position swap**, not a fractional-index scheme — correct
  and simple at demo scale, noted (not required) as a place to go further at larger list sizes,
  matching the reference web app's own documented limitation.
