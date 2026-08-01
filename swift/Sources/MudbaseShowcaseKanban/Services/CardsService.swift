import Foundation
import MudbaseSDK

/// Reads and writes against the `cards` collection. Mirrors `../web/src/hooks/useCards.ts`.
struct CardsService {
    private let gateway: CollectionsGateway
    private let activityService: ActivityService
    let boardId: String

    init(config: AppConfig, activityService: ActivityService) {
        gateway = CollectionsGateway(projectId: config.projectId, collectionId: config.cardsCollectionId)
        self.activityService = activityService
        boardId = config.boardId
    }

    /// All cards for the single shared board, ascending by in-column order — fetched once and
    /// grouped client-side by `listId` (see `BoardViewModel.refresh`), rather than one query per
    /// column. Mirrors `../web/src/hooks/useCards.ts`'s `useBoardCards`.
    func fetchAll() async throws(ErrorResponse) -> [BoardCard] {
        let result = try await gateway.list(filter: ["boardId": .string(boardId)], sort: "position")
        return result.documents.map(BoardCard.init(document:)).sorted { $0.position < $1.position }
    }

    /// Owner/member: creates a new card at the end of a column.
    @discardableResult
    func create(
        listId: String,
        listName: String,
        position: Int,
        title: String,
        description: String?,
        assigneeId: String?,
        assigneeName: String?,
        actor: ActivityService.ActorInfo
    ) async throws(ErrorResponse) -> BoardCard {
        var fields: [String: JSONValue?] = [
            "boardId": .string(boardId),
            "listId": .string(listId),
            "title": .string(title),
            "position": .int(position),
            "createdById": .string(actor.actorId),
            "createdByName": .string(actor.actorName),
        ]
        if let description, !description.isEmpty { fields["description"] = .string(description) }
        if let assigneeId, let assigneeName {
            fields["assigneeId"] = .string(assigneeId)
            fields["assigneeName"] = .string(assigneeName)
        }
        let created = BoardCard(document: try await gateway.create(fields: fields))
        try await activityService.log(actor: actor, action: .createdCard, cardTitle: title, toList: listName)
        return created
    }

    /// Owner/member: edits a card's title/description/assignee in place. Not itself logged to the
    /// activity feed — only creation, movement, and deletion are (see `ActivityAction`).
    ///
    /// `assigneeId` is validated server-side as an ObjectId reference (verified live) — an empty
    /// string fails that check the same way an invalid slug would ("Invalid ObjectId format for
    /// assigneeId"). `.null` is the value that actually clears it — this always sends one of
    /// `.string`/`.null` (never omits the key), mirroring `useUpdateCard`'s own
    /// `assigneeId: input.assigneeId ?? null`.
    @discardableResult
    func update(_ card: BoardCard, title: String, description: String?, assigneeId: String?, assigneeName: String?) async throws(ErrorResponse) -> BoardCard {
        let fields: [String: JSONValue?] = [
            "title": .string(title),
            "description": .string(description ?? ""),
            "assigneeId": assigneeId.map(JSONValue.string) ?? .null,
            "assigneeName": assigneeName.map(JSONValue.string) ?? .null,
        ]
        return BoardCard(document: try await gateway.update(documentId: card.id, fields: fields))
    }

    /// Owner/member: deletes a card.
    func delete(_ card: BoardCard, listName: String, actor: ActivityService.ActorInfo) async throws(ErrorResponse) {
        try await gateway.delete(documentId: card.id)
        try await activityService.log(actor: actor, action: .deletedCard, cardTitle: card.title, fromList: listName)
    }

    /// Cascades a list deletion — cards have nowhere else to live once their column is gone (see
    /// `ListsService.delete`). Mirrors `useDeleteList`'s own plain `client.deleteDocument` loop,
    /// which intentionally does not log a per-card activity entry — only the list-level
    /// `deleted_list` entry is written for the whole operation.
    func rawDelete(_ card: BoardCard) async throws(ErrorResponse) {
        try await gateway.delete(documentId: card.id)
    }

    /// Owner/member: moves a card to a different column, appended to the end of it. Every move
    /// writes both `listId` and `position` and appends a `moved` activity entry.
    @discardableResult
    func move(
        _ card: BoardCard,
        fromListName: String,
        toListId: String,
        toListName: String,
        newPosition: Int,
        actor: ActivityService.ActorInfo
    ) async throws(ErrorResponse) -> BoardCard {
        let updated = BoardCard(document: try await gateway.update(
            documentId: card.id,
            fields: ["listId": .string(toListId), "position": .int(newPosition)]
        ))
        try await activityService.log(actor: actor, action: .moved, cardTitle: card.title, fromList: fromListName, toList: toListName)
        return updated
    }

    /// Owner/member: reorders a card up/down within its own column by swapping `position` with
    /// the adjacent card. Still logs a `moved` activity entry (`fromList == toList`).
    func reorder(_ card: BoardCard, with neighbor: BoardCard, listName: String, actor: ActivityService.ActorInfo) async throws(ErrorResponse) {
        _ = try await gateway.update(documentId: card.id, fields: ["position": .int(neighbor.position)])
        _ = try await gateway.update(documentId: neighbor.id, fields: ["position": .int(card.position)])
        try await activityService.log(actor: actor, action: .moved, cardTitle: card.title, fromList: listName, toList: listName)
    }
}
