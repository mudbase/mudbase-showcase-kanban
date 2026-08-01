import Foundation
import MudbaseSDK

/// Thin wrapper over `AuthenticationAPI`'s async/await calls. Kept separate from `SessionStore`
/// (which owns observable app state) so the actual network calls stay unit-testable independent
/// of SwiftUI/Observation. Ported from the sibling Swift ports' `Networking/AuthGateway.swift`,
/// trimmed to what this app needs: this app has no anonymous/guest session (every one of its three
/// roles — `owner`/`member`/`viewer` — requires a real login, see `SessionStore` doc comments) and
/// ships no in-app registration UI (the task's three demo accounts are already provisioned), so
/// `loginAnonymous()`/`registerCustomer()` are not ported.
struct AuthGateway {
    let projectId: String

    struct LoginResult {
        let accessToken: String
        let refreshToken: String
    }

    /// `POST /api/auth/local/login`.
    func login(email: String, password: String) async throws(ErrorResponse) -> LoginResult {
        let response = try await AuthenticationAPI.loginLocalUser(
            loginLocalUserRequest: LoginLocalUserRequest(email: email, password: password, projectId: projectId)
        )
        guard let token = response.token, let refreshToken = response.refreshToken else {
            throw ErrorResponse.error(-2, nil, nil, MudbaseClientError.missingTokenInResponse)
        }
        return LoginResult(accessToken: token, refreshToken: refreshToken)
    }

    /// `GET /api/auth/local/session` — the call that returns this project's custom role
    /// (`owner`/`member`/`viewer`) together with the rest of the signed-in user, matching what
    /// `../web/src/lib/mudbase.ts`'s `getSession()` returns as `user.customRole`.
    func currentUser() async throws(ErrorResponse) -> AppUser {
        let response = try await AuthenticationAPI.getLocalSession(projectId: projectId)
        guard let userJSON = response.user, let user = AppUser(json: userJSON) else {
            throw ErrorResponse.error(-2, nil, nil, MudbaseClientError.malformedSessionUser)
        }
        return user
    }

    /// `POST /api/auth/refresh` — rotates the refresh token on every use (platform-enforced,
    /// single-use); the caller is responsible for persisting the new pair.
    func refresh(refreshToken: String) async throws(ErrorResponse) -> LoginResult {
        let response = try await AuthenticationAPI.refreshToken(refreshTokenRequest: RefreshTokenRequest(refreshToken: refreshToken))
        guard let token = response.token, let newRefreshToken = response.refreshToken else {
            throw ErrorResponse.error(-2, nil, nil, MudbaseClientError.missingTokenInResponse)
        }
        return LoginResult(accessToken: token, refreshToken: newRefreshToken)
    }

    /// `POST /api/auth/local/logout` — best-effort; callers clear local state regardless of outcome.
    func logout() async throws(ErrorResponse) {
        _ = try await AuthenticationAPI.logoutLocalUser()
    }
}

enum MudbaseClientError: Error, Equatable {
    case missingTokenInResponse
    case malformedSessionUser
}
