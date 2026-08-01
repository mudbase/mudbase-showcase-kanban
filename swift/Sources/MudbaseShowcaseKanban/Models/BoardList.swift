import Foundation

/// One board column. Mirrors `../web/src/types/list.ts`'s `BoardList` interface.
struct BoardList: Identifiable, Equatable, Sendable {
    let id: String
    let boardId: String
    var name: String
    var position: Int
    let createdAt: Date?

    init(document: MudbaseDocument) {
        id = document.id
        boardId = document.string("boardId") ?? ""
        name = document.string("name") ?? ""
        position = document.int("position") ?? 0
        createdAt = document.createdAt
    }
}
