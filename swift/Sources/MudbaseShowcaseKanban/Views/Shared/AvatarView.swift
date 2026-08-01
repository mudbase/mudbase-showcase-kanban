import SwiftUI

/// Mirrors `../web/src/components/ui/avatar.tsx` — there is no `users` collection, so every
/// avatar in this app is a plain initials badge rather than a fetched profile image (see
/// `../web/plan/build-plan.md` "Known Limitations").
struct AvatarView: View {
    let name: String
    var size: CGFloat = 28

    var body: some View {
        Circle()
            .fill(Color.accentColor.opacity(0.2))
            .frame(width: size, height: size)
            .overlay(
                Text(initials(name))
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            )
    }
}
