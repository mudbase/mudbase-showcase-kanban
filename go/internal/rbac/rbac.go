// Package rbac defines this app's three role slugs and the operations each one may perform. This
// is a server-side mirror of the reference web app's src/lib/rbac.ts, used two ways in this app:
// (1) internal/server/middleware.go's requireRole gates every write route before a handler ever
// runs (the "server-side enforcement" the task requires, not just hidden template controls), and
// (2) the page templates read the same CanManage*/IsReadOnly flags to decide what to render.
// Neither of those is the real security boundary - Mudbase's own collection permissions are (see
// mbase.IsForbidden) - this package exists purely for defense-in-depth and correct UX, exactly as
// documented in plan/build-plan.md's "RBAC Matrix".
package rbac

// Role slugs this project's Multi-Role auth is configured with.
const (
	RoleOwner  = "owner"
	RoleMember = "member"
	RoleViewer = "viewer"
)

// CanManageLists reports whether role may create/rename/delete/reorder board columns.
func CanManageLists(role string) bool {
	return role == RoleOwner
}

// CanManageCards reports whether role may create/edit/delete/move cards.
func CanManageCards(role string) bool {
	return role == RoleOwner || role == RoleMember
}

// IsReadOnly reports whether role (or no role at all) can only ever read the board.
func IsReadOnly(role string) bool {
	return role == RoleViewer || role == ""
}

// Label renders a role slug for display, "Unknown" for anything unrecognized (including "").
func Label(role string) string {
	switch role {
	case RoleOwner:
		return "Owner"
	case RoleMember:
		return "Member"
	case RoleViewer:
		return "Viewer"
	default:
		return "Unknown"
	}
}

// IsValid reports whether role is one of this app's three known slugs.
func IsValid(role string) bool {
	return role == RoleOwner || role == RoleMember || role == RoleViewer
}
