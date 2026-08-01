import { appRoleSchema, type AppRole } from "@/api/schemas";

/**
 * Client-side mirror of the RBAC matrix Mudbase's own collection permissions
 * already enforce server-side (see plan/build-plan.md). This exists purely to
 * hide/disable controls a role cannot use and to show a clear reason why — it
 * is NOT the security boundary. A raw API call bypassing this UI is still
 * rejected by the platform; see the smoke test in build-plan.md. Byte-for-byte
 * port of web/src/lib/rbac.ts.
 */
export function canManageLists(role: AppRole | null): boolean {
  return role === "owner";
}

export function canManageCards(role: AppRole | null): boolean {
  return role === "owner" || role === "member";
}

export function isReadOnly(role: AppRole | null): boolean {
  return role === "viewer" || role === null;
}

export function roleLabel(role: AppRole | null): string {
  if (role === "owner") return "Owner";
  if (role === "member") return "Member";
  if (role === "viewer") return "Viewer";
  return "Unknown";
}

export function isAppRole(value: string | null | undefined): value is AppRole {
  return appRoleSchema.safeParse(value).success;
}
