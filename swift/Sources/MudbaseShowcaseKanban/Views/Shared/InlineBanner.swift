import SwiftUI

/// A non-blocking inline message — used for form-level submit errors (`LoginView`) and the
/// "Read-only" role notice (`BoardView`), as distinct from `InlineErrorView`'s full-screen retry
/// state.
struct InlineBanner: View {
    let message: String
    var isDestructive: Bool = true

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: isDestructive ? "exclamationmark.circle" : "info.circle")
            Text(message)
                .font(.subheadline)
        }
        .foregroundStyle(isDestructive ? Color.red : Color.secondary)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            (isDestructive ? Color.red : Color.secondary).opacity(0.1),
            in: RoundedRectangle(cornerRadius: 8)
        )
    }
}
