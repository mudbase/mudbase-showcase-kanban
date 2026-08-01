import SwiftUI

/// Rendered instead of `RootView` when `AppConfig.load()` fails — see `AppConfig`'s doc comment
/// for why config is only checked at runtime rather than causing a build failure.
struct ConfigurationRequiredView: View {
    let error: ConfigurationError

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "gearshape.2")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Configuration Required")
                .font(.title2.bold())
            Text(error.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
