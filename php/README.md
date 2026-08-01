# Mudbase Showcase — Kanban (PHP)

A realtime-data team task board (Kanban) built **entirely on [Mudbase](https://www.mudbase.dev)** —
auth, database, and role-based access control — with **zero custom backend**, reimplemented as a
plain, server-rendered PHP application. This is a port of the reference Next.js app in `../web`;
see that project for the canonical data model and API contract.

## Stack

Plain PHP 8.1+ (no framework — no Laravel/Symfony), PHP's built-in dev server for local
development, and the real generated `mudbase/sdk` Composer package (the same SDK used by the
sibling `mudbase-showcase-social/php` and `mudbase-showcase-ecommerce/php` ports — this project
mirrors that architecture: `Router` → `Controllers` → `View` + plain `.php` view files, a
request-scoped `AppContext`, and a `MudbaseClient` wrapper around the SDK).

Auth is session-based: the Mudbase JWT pair lives in native PHP `$_SESSION`, not `localStorage` —
there is no client-side JavaScript auth flow, and in fact **no client-side JavaScript at all** in
this app. Every interaction — sign in, create/rename/delete a list, create/edit/delete/move a
card — is a plain HTML `<form>` POST.

## What it demonstrates

| Feature | Mudbase capability | Where |
|---|---|---|
| Three-role auth (owner / member / viewer) | Multi-Role login (`POST /api/auth/local/login`, `user.customRole`) | `src/Controllers/AuthController.php`, `src/Http/AppContext.php` |
| No anonymous/guest read — every role signs in | `GET /api/auth/local/session` | `src/Http/AppContext::requireSignIn()` |
| Board columns (lists), owner-managed | Collection CRUD, `lists` | `src/Controllers/BoardController.php` (createList/renameList/deleteList/moveList) |
| Card CRUD (owner + member) | Collection CRUD, `cards` | `BoardController` (createCard/editCard/deleteCard) |
| Move card between lists / reorder in place | `PATCH` on `listId`/`position` + an `activity` row per move | `BoardController::moveCard` |
| Reverse-chronological activity log | Collection read, `sort: "-createdAt"` | `src/Controllers/ActivityController.php` |
| Role-aware UI, server-enforced | Mudbase's own per-role collection permissions | `src/Support/Rbac.php`, `src/views/board.php` |

## RBAC matrix

| Action | owner | member | viewer |
|---|---|---|---|
| Read lists / cards / activity | ✅ | ✅ | ✅ |
| Create / rename / delete / reorder lists | ✅ | ❌ | ❌ |
| Create / edit / delete / move cards | ✅ | ✅ | ❌ |

`src/Support/Rbac.php` only hides/disables controls a role cannot use in the rendered HTML.
**Controllers never pre-check role before attempting a write** — they call the same
`MudbaseClient` method a permitted role would use and let Mudbase's own collection permissions
return the real `403` if the signed-in role isn't allowed. This is the actual security boundary —
verified live (see "Live smoke test" below) with a raw authenticated request that bypasses every
form this app renders.

## Getting started

This app expects a Mudbase project already provisioned with:

1. Local auth enabled with the Multi-Role feature, three role slugs: `owner`, `member`, `viewer`.
2. Three collections — `lists`, `cards`, `activity` — with the field shapes documented in
   `plan/build-plan.md`, each role granted the permissions in the RBAC matrix above.
3. A `boards` collection with exactly one document, whose id is your `MUDBASE_BOARD_ID`.

```bash
composer install
cp .env.example .env   # fill in your own provisioned project's IDs
php -S localhost:8080 -t public public/router.php
```

Then visit `http://localhost:8080`. Sign in with one of the three demo accounts on the login page
(one-click forms, or type credentials manually) — see `plan/build-plan.md` for account details and
the RBAC verification notes.

## Live smoke test

See `plan/build-plan.md` → "Live smoke test results" for the full account-by-account,
request-by-request verification against the real project, including a raw authenticated write
attempt as the `viewer` role proving Mudbase's own collection permissions reject it server-side —
not just a hidden UI form.

## Known limitations (real platform/architecture constraints, not bugs)

See `plan/build-plan.md` → "Known Limitations":

- **No realtime.** The reference Next.js app subscribes to `lists`/`cards`/`activity` over
  Socket.IO for live updates. The generated PHP SDK ships no realtime client, and a
  server-rendered app has no persistent connection to attach one to — every mutation already
  redirects (`303`) back to a fresh page load, which shows the latest state.
- **No `users` collection** — assignee/creator/actor display names are denormalized onto the row
  that references them at write time.
- **Same-list reorder** uses a simple two-write position swap rather than a fractional-index
  scheme (fine at demo scale).
- **No registration UI** — the task's three demo accounts already exist on the live project; this
  app only signs in, it never signs up.

## Design choice: forms and disclosures, not drag-and-drop or JavaScript

Cards move via "▲"/"▼" same-list reorder forms and a "Move to…" `<select>` + submit form for
cross-list moves — no `@dnd-kit/core`-style pointer-drag gesture and no client JavaScript at all.
Column rename and card edit use a native `<details>/<summary>` disclosure instead of a JS-toggled
modal. This is a deliberate, dependency-light choice that stays fully keyboard- and
screen-reader-operable — see `plan/build-plan.md` → "Stack Decisions" for the full rationale.

## Security

- CSRF token on every state-changing form, verified before any controller logic runs.
- Open-redirect guard (`Response::redirectToSafe()`) on the login `redirectTo` value.
- Session id regenerated on login.
- All dynamic output escaped via `View::escape()` — no raw interpolation of user content anywhere.
- Authorization is enforced server-side by Mudbase's own collection permissions; this app's
  `isSignedIn()`/`Rbac` checks are UX gating (hide controls, redirect to `/login`), not the
  security boundary.

## Environment Variables

See `.env.example`.
