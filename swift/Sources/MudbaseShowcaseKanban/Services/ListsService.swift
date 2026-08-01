import Foundation
import MudbaseSDK

/// Reads and writes against the `lists` collection. Mirrors `../web/src/hooks/useLists.ts`.
struct ListsService {
    private let gateway: CollectionsGateway
    private let activityService: ActivityService
    let boardId: String

    init(config: AppConfig, activityService: ActivityService) {
        gateway = CollectionsGateway(projectId: config.projectId, collectionId: config.listsCollectionId)
        self.activityService = activityService
        boardId = config.boardId
    }

    /// All lists for the single shared board, ascending by column order.
    func fetchAll() async throws(ErrorResponse) -> [BoardList] {
        let result = try await gateway.list(filter: ["boardId": .string(boardId)], sort: "position")
        return result.documents.map(BoardList.init(document:)).sorted { $0.position < $1.position }
    }

    /// Owner-only: creates a new column at the end of the board.
    @discardableResult
    func create(name: String, position: Int, actor: ActivityService.ActorInfo) async throws(ErrorResponse) -> BoardList {
        let created = BoardList(document: try await gateway.create(fields: [
            "boardId": .string(boardId),
            "name": .string(name),
            "position": .int(position),
        ]))
        try await activityService.log(actor: actor, action: .createdList, toList: name)
        return created
    }

    /// Owner-only: renames a column.
    @discardableResult
    func rename(_ list: BoardList, to newName: String, actor: ActivityService.ActorInfo) async throws(ErrorResponse) -> BoardList {
        let updated = BoardList(document: try await gateway.update(documentId: list.id, fields: ["name": .string(newName)]))
        try await activityService.log(actor: actor, action: .renamedList, fromList: list.name, toList: newName)
        return updated
    }

    /// Owner-only: swaps this list's position with an adjacent one (left/right reorder). Not
    /// logged to the activity feed, mirroring `useReorderList` (only list create/rename/delete
    /// are logged, not reorder).
    func reorder(_ list: BoardList, with neighbor: BoardList) async throws(ErrorResponse) {
        _ = try await gateway.update(documentId: list.id, fields: ["position": .int(neighbor.position)])
        _ = try await gateway.update(documentId: neighbor.id, fields: ["position": .int(list.position)])
    }

    /// Owner-only: deletes a column and cascades to every card inside it — a list's cards have
    /// nowhere else to live once the column is gone, there's no "uncategorized" list to fall back
    /// to. Mirrors `useDeleteList`.
    func delete(_ list: BoardList, cardsInList: [BoardCard], cardsService: CardsService, actor: ActivityService.ActorInfo) async throws(ErrorResponse) {
        for card in cardsInList {
            try await cardsService.rawDelete(card)
        }
        try await gateway.delete(documentId: list.id)
        try await activityService.log(actor: actor, action: .deletedList, fromList: list.name)
    }
}
