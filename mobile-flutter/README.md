# Mudbase Showcase — Kanban (Flutter)

A Flutter reimplementation of the [Mudbase Showcase Kanban team task board](../web) — multi-role
RBAC (owner/member/viewer), lists and cards, card movement, and a realtime activity log — talking
directly to `cloud.mudbase.dev` through the real, generated **Mudbase Dart SDK** (`mudbase_sdk`,
[github.com/mudbase/mudbase-sdk](https://github.com/mudbase/mudbase-sdk), `dart/` subdirectory),
with **zero custom backend**.

## Stack

Flutter + Dart, Riverpod (`flutter_riverpod`, no code generation) for state, go_router for
navigation, `flutter_secure_storage` for the auth token, `socket_io_client` for the realtime board
and activity feed. Same architecture as the sibling `mudbase-showcase-social` Flutter port — see
"Architecture decisions" below for why plain Riverpod rather than `riverpod_generator`/`freezed`.

## Setup

The Mudbase Dart SDK is **not published to pub.dev** — `pubspec.yaml` references it as a relative
path dependency assuming a sibling-clone layout:

```yaml
mudbase_sdk:
  path: ../../mudbase-sdk/dart
```

`mobile-flutter/` sits one level inside the `mudbase-showcase-kanban` repo, so reaching a flat
sibling of that repo takes exactly two `../` segments (`mobile-flutter/` → `mudbase-showcase-kanban/`
→ parent → `mudbase-sdk/dart`).

Before anything else, clone `mudbase-sdk` as a sibling of `mudbase-showcase-kanban` itself (same
parent directory):

```bash
# from the directory that contains mudbase-showcase-kanban/
git clone https://github.com/mudbase/mudbase-sdk.git
```

So the layout looks like:

```
some-parent-dir/
├── mudbase-sdk/
│   └── dart/                  ← the SDK pubspec.yaml lives here
└── mudbase-showcase-kanban/
    └── mobile-flutter/        ← this app
```

Then:

```bash
cd mobile-flutter

# First time only (or after upgrading Flutter) - generates/refreshes the
# android/, ios/, etc. platform folders. Safe to re-run.
flutter create .

flutter pub get

cp dart_define.example.json dart_define.json
# dart_define.example.json already contains this showcase's real,
# already-provisioned project/collection/board ids (they're public, not
# secrets — see "Security" below). Override only if pointing at your own
# project.

flutter run --dart-define-from-file=dart_define.json
```

### Config (`--dart-define-from-file`, this project's Flutter convention)

Never a runtime `.env` file — every value is read via `String.fromEnvironment` in
`lib/config/env_config.dart`, which also defaults every key to this showcase's real,
already-provisioned project (unlike the sibling social/ecommerce ports, which require every value
with no default since those target a generic reusable project). `dart_define.example.json`
documents every key:

| Key | Notes |
|---|---|
| `MUDBASE_PROJECT_ID` | Not a secret — same as the web app's `NEXT_PUBLIC_MUDBASE_PROJECT_ID`. |
| `LISTS_COLLECTION_ID` | |
| `CARDS_COLLECTION_ID` | |
| `ACTIVITY_COLLECTION_ID` | |
| `BOARD_ID` | The single shared board's real ObjectId — see `plan/build-plan.md`. |
| `MUDBASE_BASE_URL` | Defaults to `https://cloud.mudbase.dev`. |

`main()` calls `EnvConfig.assertConfigured()` before `runApp` and fails fast with a clear message
if any required key is somehow left empty.

There is **no secret of any kind in this app** — every value above is safe to ship in a mobile
bundle (see "Security" below).

## Demo accounts

Sign in as any of the three already-registered, already-verified roles from the login screen's
quick-fill buttons, or type the credentials manually:

| Role | Email | Password |
|---|---|---|
| Owner | `kanban.owner.demo@gmail.com` | `KanbanTest123!` |
| Member | `kanban.member.demo@gmail.com` | `KanbanTest123!` |
| Viewer | `kanban.viewer.demo@gmail.com` | `KanbanTest123!` |

This app does not implement registration — see `plan/build-plan.md` "Stack Decisions" for why.

## What it demonstrates

| Feature | Mudbase capability | Where |
|---|---|---|
| Three-role auth (owner/member/viewer), no anonymous session | `POST /api/auth/local/login`, `GET /api/auth/session` | `lib/features/auth/`, `lib/core/rbac.dart` |
| Board columns (lists), owner-managed | Collection CRUD, `lists` | `lib/data/repositories/list_repository.dart`, `lib/features/board/widgets/list_column.dart` |
| Card CRUD (owner + member) | Collection CRUD, `cards` | `lib/data/repositories/card_repository.dart`, `lib/features/board/widgets/card_editor_sheet.dart` |
| Move card between lists / reorder in place | `PATCH` on `listId`/`position` + an `activity` row per move | `lib/features/board/board_controller.dart` |
| Reverse-chronological activity log | Collection read, `sort: "-createdAt"` | `lib/features/activity/` |
| Realtime board + activity | Socket.IO `subscribe:collection` + `db:create`/`db:update`/`db:delete` | `lib/core/mudbase_socket_service.dart`, `lib/features/board/board_controller.dart`, `lib/features/activity/activity_controller.dart` |
| Role-aware UI, server-enforced | Mudbase's own per-role collection permissions | `lib/core/rbac.dart`, `lib/features/board/board_screen.dart` |

## RBAC matrix

| Action | owner | member | viewer |
|---|---|---|---|
| Read lists / cards / activity | ✅ | ✅ | ✅ |
| Create / rename / delete / reorder lists | ✅ | ❌ | ❌ |
| Create / edit / delete / move cards | ✅ | ✅ | ❌ |

The UI hides write controls a role cannot use; Mudbase's own collection permissions are the real
enforcement boundary — verified live with raw repository calls bypassing the UI entirely, see
`plan/build-plan.md` → "Live Smoke Test Results".

## Design choice: button/menu-based card movement, not drag-and-drop

Cards move via an up/down reorder pair and a "Move to…" `PopupMenuButton`, not a pointer-drag
gesture. This mirrors the reference web app's own deliberate choice (button/dropdown instead of
`@dnd-kit/core`) — dependency-light and fully accessible, and consistent across every port of this
showcase. See `plan/build-plan.md` → "Stack Decisions" for the full rationale.

## Realtime

`BoardController` subscribes to the `lists` and `cards` collections' Socket.IO rooms and refetches
the whole board on any `db:create`/`db:update`/`db:delete` event; `ActivityFeedController` does the
same for the `activity` collection on the Activity tab. Same `subscribe:collection` contract as the
web app's `mudbase-socket.ts`, ported to Dart via `socket_io_client`.

## Known limitations (real platform constraints, not bugs)

See `plan/build-plan.md` → "Known Limitations" — no `users` collection (names are denormalized at
write time), same-list reorder uses a simple two-write position swap rather than a
fractional-index scheme (fine at demo scale), and this project's login endpoint is rate-limited
(5 requests / 15 minutes per IP) and shared across every language/platform port's own smoke test.

## Architecture decisions

- **Riverpod without code generation**, same reason as the sibling `mudbase-showcase-social` port:
  this environment has no Flutter SDK installed to iteratively verify `build_runner` output
  locally — every provider and model here is verifiable by `dart analyze` alone (and, for the
  Flutter-free layer, actually was — see `plan/build-plan.md` "Testing Note").
- **One `BoardController` for both lists and cards** rather than two separate controllers — a
  Flutter screen needs one `AsyncValue` to build against; see `plan/build-plan.md` for why this
  differs from the web app's two independent query hooks.
- **No `RegisterScreen`, no `registerWithRole` method on `AuthService`** — this app's task brief
  explicitly reuses three pre-registered demo accounts and forbids creating new ones, so a signup
  code path would be genuinely dead code here, unlike the sibling ports (which do implement
  registration for their own, differently-scoped tasks).

## Testing

`test/models/` and `test/core/` use plain `package:test` (not `flutter_test`) specifically so they
run with **plain `dart test`, independent of the Flutter SDK** — and they were: **56/56 passed**
in this build (see `plan/build-plan.md` "Testing Note" for exactly how, since this project's own
`pubspec.yaml` can't `pub get` without Flutter installed either).

```bash
dart test test/models test/core   # runs today, no Flutter SDK needed
flutter test                      # once Flutter is installed
```

`tool/manual_test.dart` is a standalone live smoke-test script against the real project — see
`plan/build-plan.md` → "Live Smoke Test Results"; it was executed for real during this build via
the scratch-package technique documented there, and will run directly with `dart run` (or
`flutter pub get` first) once Flutter is installed in a given environment.

## Verification

```bash
dart format --set-exit-if-changed .
dart analyze     # requires `flutter pub get` first once Flutter is installed
flutter test
```

## License

MIT — see the repo root [LICENSE](../LICENSE).
