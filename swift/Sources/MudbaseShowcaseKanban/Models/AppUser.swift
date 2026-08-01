import Foundation
import MudbaseSDK

/// Project end-user, as returned by `GET /api/auth/local/session`. The generated SDK types that
/// endpoint's `user` field as a raw `JSONValue` rather than a fixed struct — unlike org/platform
/// users, project end-users carry whatever custom roles the project's Multi-Role feature defines,
/// so the SDK can't model that shape ahead of time. This type is this app's own typed read of that
/// JSON. Mirrors `../web/src/lib/mudbase.ts`'s `UserObject`.
struct AppUser: Sendable, Equatable, Identifiable {
    let id: String
    let email: String
    let firstName: String
    let lastName: String
    /// One of `"owner"`/`"member"`/`"viewer"` — this app has no anonymous session, so unlike the
    /// sibling social Swift port's `AppUser`, this is never expected to be `nil` for a
    /// successfully-authenticated user (see `AppRole` in `Support/RBAC.swift`).
    let customRole: String?
    let emailVerified: Bool

    var displayName: String {
        let name = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? email : name
    }

    var role: AppRole? {
        customRole.flatMap(AppRole.init(rawValue:))
    }

    init?(json: JSONValue) {
        guard let dict = json.dictionaryValue,
              let id = dict["_id"]?.stringValue ?? dict["id"]?.stringValue
        else {
            return nil
        }
        self.id = id
        self.email = dict["email"]?.stringValue ?? ""
        self.firstName = dict["firstName"]?.stringValue ?? ""
        self.lastName = dict["lastName"]?.stringValue ?? ""
        self.emailVerified = dict["emailVerified"]?.boolValue ?? false
        self.customRole = dict["customRole"]?.stringValue
    }
}
