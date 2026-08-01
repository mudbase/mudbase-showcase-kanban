import SwiftUI

/// Two tabs, mirroring `../web/src/components/layout/Header.tsx`'s nav: Board (the main board
/// screen) and Activity (the reverse-chronological feed).
struct MainTabView: View {
    let config: AppConfig
    let user: AppUser

    var body: some View {
        TabView {
            NavigationStack {
                BoardView(config: config, currentUser: user)
            }
            .tabItem { Label("Board", systemImage: "square.grid.3x3.fill") }

            NavigationStack {
                ActivityView(config: config)
            }
            .tabItem { Label("Activity", systemImage: "clock.arrow.circlepath") }
        }
    }
}
