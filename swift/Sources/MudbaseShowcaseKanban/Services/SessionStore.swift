import Foundation
import MudbaseSDK

/// Owns the app's auth state end to end: bootstrap-from-Keychain at launch, login, logout. The
/// SwiftUI equivalent of `../web/src/lib/mudbase-provider.tsx` + `../web/src/hooks/useAuth.ts`
/// combined.
///
/// Unlike the sibling social/ecommerce Swift ports' `SessionStore`, this app has **no
/// anonymous/guest session at all** — every one of the three roles (`owner`/`member`/`viewer`)
/// requires a real login, because every one of Mudbase's own collection permissions on this
/// project's `lists`/`cards`/`activity` collections requires authentication (verified live in the
/// web app's own build — see `../web/plan/build-plan.md`). `user == nil` after `bootstrap()`
/// completes therefore always means "show the sign-in screen," never "browsing as guest."
@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var user: AppUser?
    @Published private(set) var isBootstrapping = true

    private let authGateway: AuthGateway
    private let tokenStore: KeychainTokenStore

    init(config: AppConfig, tokenStore: KeychainTokenStore = KeychainTokenStore()) {
        self.authGateway = AuthGateway(projectId: config.projectId)
        self.tokenStore = tokenStore
    }

    var role: AppRole? { user?.role }

    /// Called once at app launch. Configures the shared `AccessTokenCoordinator` unconditionally
    /// (even before any session exists yet) — see that type's doc comment — since it must be
    /// ready before *any* authenticated call in the app. Restores a stored token pair if any,
    /// validating it against the session endpoint; a 401 (expired access token) is transparently
    /// refreshed and retried once by the coordinator. If there's nothing stored, or the stored
    /// session turns out to be truly invalid, `user` stays `nil` — `RootView` renders `LoginView`.
    func bootstrap() async {
        defer { isBootstrapping = false }
        await AccessTokenCoordinator.shared.configure(authGateway: authGateway, tokenStore: tokenStore)

        guard let stored = tokenStore.load() else {
            user = nil
            return
        }
        MudbaseSDKBootstrap.setAccessToken(stored.accessToken)
        let gateway = authGateway
        do {
            user = try await AccessTokenCoordinator.shared.perform { () async throws(ErrorResponse) in
                try await gateway.currentUser()
            }
        } catch {
            // Whether this was a 401 that survived the coordinator's own refresh attempt, or any
            // other failure (offline, a transient 5xx), there is no fallback session to fall back
            // to in this app (unlike the sibling ports' anonymous guest) — either way the user
            // needs to sign in again. Clearing local state here (rather than only inside the
            // coordinator's own 401 path) also covers a transport-level failure that never made it
            // to a 401 at all.
            tokenStore.clear()
            MudbaseSDKBootstrap.clearAccessToken()
            user = nil
        }
    }

    func login(email: String, password: String) async -> Result<Void, MudbaseAPIError.DisplayableError> {
        do {
            let result = try await authGateway.login(email: email, password: password)
            tokenStore.save(.init(accessToken: result.accessToken, refreshToken: result.refreshToken))
            MudbaseSDKBootstrap.setAccessToken(result.accessToken)
            user = try await authGateway.currentUser()
            return .success(())
        } catch {
            return .failure(MudbaseAPIError.map(error))
        }
    }

    func logout() async {
        _ = try? await authGateway.logout()
        tokenStore.clear()
        MudbaseSDKBootstrap.clearAccessToken()
        user = nil
    }
}
