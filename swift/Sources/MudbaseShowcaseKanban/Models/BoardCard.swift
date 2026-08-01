import Foundation

/// A single task card within a list. Mirrors `../web/src/types/card.ts`'s `BoardCard` interface.
/// `assigneeId`/`assigneeName` being `nil` is a real, distinct state from "was never set" vs.
/// "was explicitly cleared" only matters at the write boundary (see `CardsService.update`) — once
/// read back, both cases collapse to `nil` here, same as the web type's `string | null | undefined`
/// collapsing to `undefined`-shaped optionality for read purposes.
struct BoardCard: Identifiable, Equatable, Sendable {
    let id: String
    let boardId: String
    var listId: String
    var title: String
    var description: String?
    var position: Int
    var assigneeId: String?
    var assigneeName: String?
    let createdById: String
    let createdByName: String
    let createdAt: Date?

    init(document: MudbaseDocument) {
        id = document.id
        boardId = document.string("boardId") ?? ""
        listId = document.string("listId") ?? ""
        title = document.string("title") ?? ""
        description = document.string("description")
        position = document.int("position") ?? 0
        assigneeId = document.string("assigneeId")
        assigneeName = document.string("assigneeName")
        createdById = document.string("createdById") ?? ""
        createdByName = document.string("createdByName") ?? ""
        createdAt = document.createdAt
    }
}
