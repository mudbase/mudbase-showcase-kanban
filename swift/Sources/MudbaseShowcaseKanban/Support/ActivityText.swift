import Foundation

/// Renders one activity row as a plain, readable sentence for the feed. Ports
/// `../web/src/lib/activity-text.ts`'s `describeActivity` verbatim.
func describeActivity(_ entry: ActivityEntry) -> String {
    let who = entry.actorName.isEmpty ? "Someone" : entry.actorName
    switch entry.action {
    case .createdCard:
        return "\(who) created card \"\(entry.cardTitle ?? "Untitled")\" in \(entry.toList ?? "a list")"
    case .moved:
        if let fromList = entry.fromList, let toList = entry.toList, fromList == toList {
            return "\(who) reordered \"\(entry.cardTitle ?? "a card")\" within \(toList)"
        }
        return "\(who) moved \"\(entry.cardTitle ?? "a card")\" from \(entry.fromList ?? "?") to \(entry.toList ?? "?")"
    case .deletedCard:
        return "\(who) deleted card \"\(entry.cardTitle ?? "Untitled")\" from \(entry.fromList ?? "a list")"
    case .createdList:
        return "\(who) created list \"\(entry.toList ?? "Untitled")\""
    case .renamedList:
        return "\(who) renamed list \"\(entry.fromList ?? "?")\" to \"\(entry.toList ?? "?")\""
    case .deletedList:
        return "\(who) deleted list \"\(entry.fromList ?? "Untitled")\""
    }
}

/// SF Symbol per action, mirroring the icon-per-action mapping in
/// `../web/src/components/activity/ActivityItem.tsx`.
func activityIconName(_ action: ActivityAction) -> String {
    switch action {
    case .createdCard: return "plus.circle"
    case .moved: return "arrow.left.arrow.right"
    case .deletedCard: return "trash"
    case .createdList: return "rectangle.stack.badge.plus"
    case .renamedList: return "arrow.triangle.2.circlepath"
    case .deletedList: return "rectangle.stack.badge.minus"
    }
}
