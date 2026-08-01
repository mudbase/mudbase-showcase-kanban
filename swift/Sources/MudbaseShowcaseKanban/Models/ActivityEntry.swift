import Foundation

/// Mirrors `../web/src/types/activity.ts`'s `ActivityAction` union.
enum ActivityAction: String, Sendable, Equatable {
    case createdCard = "created_card"
    case moved
    case deletedCard = "deleted_card"
    case createdList = "created_list"
    case renamedList = "renamed_list"
    case deletedList = "deleted_list"
}

/// One row in the board's activity log. Mirrors `../web/src/types/activity.ts`'s `ActivityEntry`
/// interface.
struct ActivityEntry: Identifiable, Equatable, Sendable {
    let id: String
    let boardId: String
    let actorId: String
    let actorName: String
    let action: ActivityAction
    let cardTitle: String?
    let fromList: String?
    let toList: String?
    let createdAt: Date?

    init(document: MudbaseDocument) {
        id = document.id
        boardId = document.string("boardId") ?? ""
        actorId = document.string("actorId") ?? ""
        actorName = document.string("actorName") ?? ""
        // An unrecognized action string should never happen against this app's own writes, but a
        // shared demo board could in principle carry a row from a future action this build
        // doesn't know about — `.moved` is a safe, generic fallback rather than crashing/failing
        // the whole feed over one row.
        action = ActivityAction(rawValue: document.string("action") ?? "") ?? .moved
        cardTitle = document.string("cardTitle")
        fromList = document.string("fromList")
        toList = document.string("toList")
        createdAt = document.createdAt
    }
}
