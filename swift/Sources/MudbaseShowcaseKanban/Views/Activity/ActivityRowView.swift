import SwiftUI

/// Mirrors `../web/src/components/activity/ActivityItem.tsx`.
struct ActivityRowView: View {
    let entry: ActivityEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AvatarView(name: entry.actorName, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(describeActivity(entry))
                    .font(.subheadline)
                Text(formatRelativeTime(entry.createdAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: activityIconName(entry.action))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
