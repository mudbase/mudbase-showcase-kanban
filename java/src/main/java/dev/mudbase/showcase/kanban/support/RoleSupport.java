package dev.mudbase.showcase.kanban.support;

/**
 * Server-side mirror of the RBAC matrix Mudbase's own collection permissions already enforce
 * (see plan/build-plan.md) - used both to hide/disable controls a role cannot use in the
 * templates, and (via {@link dev.mudbase.showcase.kanban.web.ForbiddenActionException}, thrown
 * from the service layer) as this Java app's own independent server-side check before a mutating
 * Mudbase call is even attempted. Neither of these is the ultimate security boundary - Mudbase's
 * own per-collection permissions are - but together they mean a request that bypasses this app's
 * UI still gets rejected by this app's own controllers/services, not merely by the platform one
 * layer further down. Mirrors ../web/src/lib/rbac.ts exactly.
 */
public final class RoleSupport {

  public static final String OWNER = "owner";
  public static final String MEMBER = "member";
  public static final String VIEWER = "viewer";

  private RoleSupport() {}

  public static boolean canManageLists(String role) {
    return OWNER.equals(role);
  }

  public static boolean canManageCards(String role) {
    return OWNER.equals(role) || MEMBER.equals(role);
  }

  public static boolean isReadOnly(String role) {
    return role == null || VIEWER.equals(role);
  }

  public static String roleLabel(String role) {
    if (OWNER.equals(role)) {
      return "Owner";
    }
    if (MEMBER.equals(role)) {
      return "Member";
    }
    if (VIEWER.equals(role)) {
      return "Viewer";
    }
    return "Unknown";
  }
}
