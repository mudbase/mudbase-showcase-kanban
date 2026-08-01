import Foundation

/// Owns the board's data (lists + cards, fetched once and grouped client-side by `listId` — same
/// as `../web/src/components/board/BoardView.tsx`) and every list/card mutation. One instance per
/// `BoardView`, constructed with the signed-in `currentUser` so every mutation can stamp
/// `actorId`/`actorName` onto its activity row without threading the session through every method
/// call.
///
/// Realtime: `../web/`'s `useBoardLive` subscribes to the `lists`/`cards`/`activity` collections'
/// Socket.IO rooms. There is no official Mudbase realtime client outside JavaScript, and the
/// sibling non-JS language ports of this same reference app already established the precedent of
/// substituting periodic polling rather than vendoring an unofficial, unaudited Socket.IO Swift
/// library as a new SwiftPM dependency (see the social Swift port's README "Realtime" section).
/// `pollTask` re-fetches the board every `pollInterval` while `BoardView` is on screen.
@MainActor
final class BoardViewModel: ObservableObject {
    @Published private(set) var lists: [BoardList] = []
    @Published private(set) var cardsByListId: [String: [BoardCard]] = [:]
    @Published private(set) var isLoading = true
    @Published private(set) var loadErrorMessage: String?
    /// Set by any failed mutation below; `CardFormView`/`ListColumnView` read and clear this after
    /// surfacing it, `BoardView` surfaces whatever is left as a fallback alert.
    @Published var actionErrorMessage: String?

    private let listsService: ListsService
    private let cardsService: CardsService
    private let activityService: ActivityService
    private let currentUser: AppUser
    private var pollTask: Task<Void, Never>?

    private static let pollInterval: Duration = .seconds(5)

    init(config: AppConfig, currentUser: AppUser) {
        let activityService = ActivityService(config: config)
        self.activityService = activityService
        self.listsService = ListsService(config: config, activityService: activityService)
        self.cardsService = CardsService(config: config, activityService: activityService)
        self.currentUser = currentUser
    }

    private var actor: ActivityService.ActorInfo {
        .init(actorId: currentUser.id, actorName: currentUser.displayName)
    }

    func start() async {
        await refresh()
        isLoading = false
        startPolling()
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.pollInterval)
                if Task.isCancelled { break }
                await self?.refresh()
            }
        }
    }

    func refresh() async {
        do {
            let fetchedLists = try await listsService.fetchAll()
            let fetchedCards = try await cardsService.fetchAll()
            lists = fetchedLists
            var grouped: [String: [BoardCard]] = [:]
            for card in fetchedCards {
                grouped[card.listId, default: []].append(card)
            }
            for key in grouped.keys {
                grouped[key]?.sort { $0.position < $1.position }
            }
            cardsByListId = grouped
            loadErrorMessage = nil
        } catch {
            loadErrorMessage = MudbaseAPIError.map(error).message
        }
    }

    // MARK: - Derived read helpers

    func cards(in list: BoardList) -> [BoardCard] {
        cardsByListId[list.id] ?? []
    }

    func otherLists(than list: BoardList) -> [BoardList] {
        lists.filter { $0.id != list.id }
    }

    var nextListPosition: Int {
        lists.isEmpty ? 0 : (lists.map(\.position).max() ?? 0) + 1
    }

    func nextCardPosition(in list: BoardList) -> Int {
        let inList = cards(in: list)
        return inList.isEmpty ? 0 : (inList.map(\.position).max() ?? 0) + 1
    }

    // MARK: - List actions (owner-only; server-enforced, see Support/RBAC.swift)

    @discardableResult
    func createList(name: String) async -> Bool {
        do {
            try await listsService.create(name: name, position: nextListPosition, actor: actor)
            await refresh()
            return true
        } catch {
            actionErrorMessage = MudbaseAPIError.map(error).message
            return false
        }
    }

    @discardableResult
    func renameList(_ list: BoardList, to newName: String) async -> Bool {
        guard newName != list.name else { return true }
        do {
            try await listsService.rename(list, to: newName, actor: actor)
            await refresh()
            return true
        } catch {
            actionErrorMessage = MudbaseAPIError.map(error).message
            return false
        }
    }

    func moveList(_ list: BoardList, toward neighbor: BoardList?) async {
        guard let neighbor else { return }
        do {
            try await listsService.reorder(list, with: neighbor)
            await refresh()
        } catch {
            actionErrorMessage = MudbaseAPIError.map(error).message
        }
    }

    func deleteList(_ list: BoardList) async {
        do {
            try await listsService.delete(list, cardsInList: cards(in: list), cardsService: cardsService, actor: actor)
            await refresh()
        } catch {
            actionErrorMessage = MudbaseAPIError.map(error).message
        }
    }

    // MARK: - Card actions (owner/member; server-enforced, see Support/RBAC.swift)

    func createCard(in list: BoardList, title: String, description: String?, assigneeName: String?) async {
        do {
            let assigneeId = assigneeName.map(pseudoObjectId)
            try await cardsService.create(
                listId: list.id,
                listName: list.name,
                position: nextCardPosition(in: list),
                title: title,
                description: description,
                assigneeId: assigneeId,
                assigneeName: assigneeName,
                actor: actor
            )
            await refresh()
        } catch {
            actionErrorMessage = MudbaseAPIError.map(error).message
        }
    }

    func updateCard(_ card: BoardCard, title: String, description: String?, assigneeName: String?) async {
        do {
            let assigneeId = assigneeName.map(pseudoObjectId)
            try await cardsService.update(card, title: title, description: description, assigneeId: assigneeId, assigneeName: assigneeName)
            await refresh()
        } catch {
            actionErrorMessage = MudbaseAPIError.map(error).message
        }
    }

    func deleteCard(_ card: BoardCard, in list: BoardList) async {
        do {
            try await cardsService.delete(card, listName: list.name, actor: actor)
            await refresh()
        } catch {
            actionErrorMessage = MudbaseAPIError.map(error).message
        }
    }

    func moveCard(_ card: BoardCard, from list: BoardList, to targetList: BoardList) async {
        do {
            try await cardsService.move(
                card,
                fromListName: list.name,
                toListId: targetList.id,
                toListName: targetList.name,
                newPosition: nextCardPosition(in: targetList),
                actor: actor
            )
            await refresh()
        } catch {
            actionErrorMessage = MudbaseAPIError.map(error).message
        }
    }

    func reorderCard(_ card: BoardCard, with neighbor: BoardCard, in list: BoardList) async {
        do {
            try await cardsService.reorder(card, with: neighbor, listName: list.name, actor: actor)
            await refresh()
        } catch {
            actionErrorMessage = MudbaseAPIError.map(error).message
        }
    }
}
