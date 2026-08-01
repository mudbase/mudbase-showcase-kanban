import Foundation

/// Role slugs this project's Multi-Role auth is configured with — see plan/build-plan.md. Mirrors
/// `../web/src/lib/mudbase.ts`'s `AppRole` type.
enum AppRole: String, Sendable, Equatable, CaseIterable {
    case owner
    case member
    case viewer
}

/// Client-side mirror of the RBAC matrix Mudbase's own collection permissions already enforce
/// server-side (see plan/build-plan.md). This exists purely to hide/disable controls a role
/// cannot use and to show a clear reason why — it is NOT the security boundary. A raw API call
/// bypassing this UI is still rejected by the platform; see `ManualLiveFlowTests` for the proof.
/// Ports `../web/src/lib/rbac.ts` verbatim.
func canManageLists(_ role: AppRole?) -> Bool {
    role == .owner
}

func canManageCards(_ role: AppRole?) -> Bool {
    role == .owner || role == .member
}

func isReadOnly(_ role: AppRole?) -> Bool {
    role == .viewer || role == nil
}

func roleLabel(_ role: AppRole?) -> String {
    switch role {
    case .owner: return "Owner"
    case .member: return "Member"
    case .viewer: return "Viewer"
    case .none: return "Unknown"
    }
}
