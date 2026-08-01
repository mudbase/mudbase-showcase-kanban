import Foundation
import MudbaseSDK

/// Reads and writes against the `activity` collection. Mirrors
/// `../web/src/hooks/useActivity.ts` (reads) and every board/card mutation hook in
/// `../web/src/hooks/useLists.ts`/`useCards.ts` that appends an activity row after its own write
/// (writes) — `ListsService`/`CardsService` both hold a reference to this type for exactly that.
struct ActivityService {
    private let gateway: CollectionsGateway
    let boardId: String

    /// Matches `../web/src/hooks/useActivity.ts`'s `FEED_LIMIT`.
    private static let feedLimit = 200

    init(config: AppConfig) {
        gateway = CollectionsGateway(projectId: config.projectId, collectionId: config.activityCollectionId)
        boardId = config.boardId
    }

    struct ActorInfo {
        let actorId: String
        let actorName: String
    }

    /// Reverse-chronological activity feed for the shared board.
    func feed(limit: Int = ActivityService.feedLimit) async throws(ErrorResponse) -> [ActivityEntry] {
        let result = try await gateway.list(filter: ["boardId": .string(boardId)], sort: "-createdAt", limit: limit)
        return result.documents.map(ActivityEntry.init(document:))
    }

    @discardableResult
    func log(actor: ActorInfo, action: ActivityAction, cardTitle: String? = nil, fromList: String? = nil, toList: String? = nil) async throws(ErrorResponse) -> ActivityEntry {
        var fields: [String: JSONValue?] = [
            "boardId": .string(boardId),
            "actorId": .string(actor.actorId),
            "actorName": .string(actor.actorName),
            "action": .string(action.rawValue),
        ]
        if let cardTitle { fields["cardTitle"] = .string(cardTitle) }
        if let fromList { fields["fromList"] = .string(fromList) }
        if let toList { fields["toList"] = .string(toList) }
        return ActivityEntry(document: try await gateway.create(fields: fields))
    }
}
