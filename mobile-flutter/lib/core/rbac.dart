/// Client-side mirror of the RBAC matrix Mudbase's own collection
/// permissions already enforce server-side (see `plan/build-plan.md` and
/// the reference web app's `src/lib/rbac.ts`). This exists purely to
/// hide/disable controls a role cannot use and to show a clear reason why -
/// it is NOT the security boundary. A raw API call bypassing this app's UI
/// entirely is still rejected by the platform; see `tool/manual_test.dart`
/// for a live proof (a viewer-token raw create attempt, 403).
library;

/// Role slugs this project's multi-role auth is configured with. Kept as
/// plain `String` constants (not a Dart `enum`) because the wire value
/// (`user.customRole`) is exactly one of these three strings already -
/// no translation layer needed between JSON and app state.
abstract final class AppRole {
  const AppRole._();

  static const String owner = 'owner';
  static const String member = 'member';
  static const String viewer = 'viewer';
}

bool isAppRole(String? value) {
  return value == AppRole.owner ||
      value == AppRole.member ||
      value == AppRole.viewer;
}

bool canManageLists(String? role) => role == AppRole.owner;

bool canManageCards(String? role) =>
    role == AppRole.owner || role == AppRole.member;

bool isReadOnly(String? role) => role == AppRole.viewer || role == null;

String roleLabel(String? role) {
  return switch (role) {
    AppRole.owner => 'Owner',
    AppRole.member => 'Member',
    AppRole.viewer => 'Viewer',
    _ => 'Unknown',
  };
}
