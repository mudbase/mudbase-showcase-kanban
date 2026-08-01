import SwiftUI

/// The Swift equivalent of `AuthGate.tsx` + `mudbase-provider.tsx`'s bootstrap effect. This app
/// has no anonymous/guest session (see `SessionStore` doc comments), so `sessionStore.user == nil`
/// after bootstrap always means "show the login screen," never "browsing as guest."
struct RootView: View {
    let config: AppConfig
    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        Group {
            if sessionStore.isBootstrapping {
                LoadingView()
            } else if let user = sessionStore.user {
                MainTabView(config: config, user: user)
            } else {
                LoginView(sessionStore: sessionStore)
            }
        }
        .task { await sessionStore.bootstrap() }
    }
}
