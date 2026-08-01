import Foundation
import Testing
@testable import MudbaseShowcaseKanban
import MudbaseSDK

/// Standalone, headless verification that exercises this app's own `Services`/`Networking` layer
/// — the exact `AuthGateway`, `ListsService`, `CardsService`, `ActivityService`, and
/// `AccessTokenCoordinator` types the SwiftUI views and view models call — directly against the
/// real, live `cloud.mudbase.dev` project. There is no iOS Simulator in this environment, so this
/// stands in for clicking through the actual UI — the same headless-verification approach the
/// sibling ecommerce/social Swift ports used.
///
/// Disabled unless `RUN_LIVE_FLOW_TEST=1` is set, since it makes real network calls against a live
/// project and writes real documents (a list, a card, several activity rows) — a plain
/// `swift test` must never do that on its own. Run it explicitly with:
///
///   RUN_LIVE_FLOW_TEST=1 swift test --filter ManualLiveFlowTests
@Suite(.serialized)
struct ManualLiveFlowTests {
    static let isEnabled = ProcessInfo.processInfo.environment["RUN_LIVE_FLOW_TEST"] == "1"

    static let config = AppConfig(
        projectId: "6a6d29b2d07caabbbdfc3f8c",
        baseURL: URL(string: "https://cloud.mudbase.dev")!,
        listsCollectionId: "6a6d29cad07caabbbdfc3f9a",
        cardsCollectionId: "6a6d29cad07caabbbdfc3fad",
        activityCollectionId: "6a6d29cbd07caabbbdfc3fc6",
        boardId: "6a6d4072d07caabbbdfc5d3c"
    )

    // The three already-verified accounts supplied for this build — see the task brief and
    // README "Provisioning". These replace the originally-spec'd `.test`-domain accounts, which
    // fail Mudbase's own login validation live (see ../web/plan/build-plan.md "Real platform
    // finding") — RBAC lives on the *role*, not the specific user, so these are functionally
    // identical test accounts.
    static let ownerEmail = "kanban.owner.demo@gmail.com"
    static let memberEmail = "kanban.member.demo@gmail.com"
    static let viewerEmail = "kanban.viewer.demo@gmail.com"
    static let sharedPassword = "KanbanTest123!"

    /// Optional pre-minted token-pair fallback per account, read from the environment — mirrors
    /// the same "fallback pre-minted tokens if login 429s" contingency the sibling social Swift
    /// port's own live verification anticipated (the auth endpoint's rate limit is a real,
    /// shared-IP budget across every language port's own verification runs against this project).
    /// When set, these are used instead of calling `authGateway.login`, so a rerun doesn't have to
    /// spend more of the shared per-IP budget.
    private static func resolveSession(authGateway: AuthGateway, email: String, accessEnvKey: String, refreshEnvKey: String) async throws -> AuthGateway.LoginResult {
        let environment = ProcessInfo.processInfo.environment
        if let accessToken = environment[accessEnvKey], let refreshToken = environment[refreshEnvKey],
           !accessToken.isEmpty, !refreshToken.isEmpty {
            return AuthGateway.LoginResult(accessToken: accessToken, refreshToken: refreshToken)
        }
        return try await authGateway.login(email: email, password: sharedPassword)
    }

    @Test(.enabled(if: ManualLiveFlowTests.isEnabled))
    @MainActor
    func fullKanbanFlow() async throws {
        MudbaseSDKBootstrap.configure(baseURL: Self.config.baseURL)

        let authGateway = AuthGateway(projectId: Self.config.projectId)
        let activityService = ActivityService(config: Self.config)
        let listsService = ListsService(config: Self.config, activityService: activityService)
        let cardsService = CardsService(config: Self.config, activityService: activityService)

        // --- Owner signs in ---
        let ownerSession = try await Self.resolveSession(authGateway: authGateway, email: Self.ownerEmail, accessEnvKey: "OWNER_ACCESS_TOKEN", refreshEnvKey: "OWNER_REFRESH_TOKEN")
        MudbaseSDKBootstrap.setAccessToken(ownerSession.accessToken)
        let owner = try await authGateway.currentUser()
        #expect(owner.role == .owner, "expected the owner account's customRole to resolve to .owner, got \(String(describing: owner.customRole))")
        let ownerActor = ActivityService.ActorInfo(actorId: owner.id, actorName: owner.displayName)

        // --- Owner reads the board (this project already carries seeded demo lists/cards from
        // the reference web app's own live smoke test — see ../web/plan/build-plan.md) ---
        var lists = try await listsService.fetchAll()
        #expect(!lists.isEmpty, "expected the shared demo board to already have at least one list")

        // Ensure there are at least two lists so this test can exercise a real cross-list move,
        // not just a same-list reorder — creates one if needed, clearly labeled as test data.
        if lists.count < 2 {
            let uniqueSuffix = UUID().uuidString.prefix(8)
            try await listsService.create(name: "Swift Live Flow Test List (\(uniqueSuffix))", position: lists.map(\.position).max().map { $0 + 1 } ?? 0, actor: ownerActor)
            lists = try await listsService.fetchAll()
        }
        #expect(lists.count >= 2, "expected at least two lists to exist for the cross-list move assertion below")

        let sourceList = lists[0]
        let targetList = lists[1]

        // --- Owner creates a card with an assignee, in the first list ---
        let uniqueSuffix = UUID().uuidString.prefix(8)
        let cardTitle = "Swift live flow test card (\(uniqueSuffix))"
        let existingCardsInSource = try await cardsService.fetchAll().filter { $0.listId == sourceList.id }
        let nextPosition = existingCardsInSource.map(\.position).max().map { $0 + 1 } ?? 0

        let assigneeName = "Swift Test Bot"
        let createdCard = try await cardsService.create(
            listId: sourceList.id,
            listName: sourceList.name,
            position: nextPosition,
            title: cardTitle,
            description: "Created by the Swift live flow test — safe to delete.",
            assigneeId: pseudoObjectId(assigneeName),
            assigneeName: assigneeName,
            actor: ownerActor
        )
        #expect(createdCard.title == cardTitle)
        #expect(createdCard.assigneeName == assigneeName)

        // --- Feed read includes the just-created card ---
        var allCards = try await cardsService.fetchAll()
        #expect(allCards.contains { $0.id == createdCard.id }, "card fetch did not include the just-created card")

        // --- Activity log includes the created_card entry ---
        var activity = try await activityService.feed()
        #expect(activity.contains { $0.action == .createdCard && $0.cardTitle == cardTitle }, "activity feed did not include a created_card entry for the new card")

        // --- Member signs in, moves the card to the other list, and clears its assignee ---
        let memberSession = try await Self.resolveSession(authGateway: authGateway, email: Self.memberEmail, accessEnvKey: "MEMBER_ACCESS_TOKEN", refreshEnvKey: "MEMBER_REFRESH_TOKEN")
        MudbaseSDKBootstrap.setAccessToken(memberSession.accessToken)
        let member = try await authGateway.currentUser()
        #expect(member.role == .member, "expected the member account's customRole to resolve to .member, got \(String(describing: member.customRole))")
        let memberActor = ActivityService.ActorInfo(actorId: member.id, actorName: member.displayName)

        let cardBeforeMove = try await cardsService.fetchAll().first { $0.id == createdCard.id }
        #expect(cardBeforeMove != nil, "member could not read the card the owner just created")

        let existingCardsInTarget = try await cardsService.fetchAll().filter { $0.listId == targetList.id }
        let targetPosition = existingCardsInTarget.map(\.position).max().map { $0 + 1 } ?? 0
        try await cardsService.move(
            cardBeforeMove!,
            fromListName: sourceList.name,
            toListId: targetList.id,
            toListName: targetList.name,
            newPosition: targetPosition,
            actor: memberActor
        )

        allCards = try await cardsService.fetchAll()
        let movedCard = allCards.first { $0.id == createdCard.id }
        #expect(movedCard?.listId == targetList.id, "expected the card's listId to reflect the cross-list move")

        activity = try await activityService.feed()
        #expect(activity.contains { $0.action == .moved && $0.cardTitle == cardTitle && $0.fromList == sourceList.name && $0.toList == targetList.name }, "activity feed did not include a moved entry for the cross-list move")

        // Member clears the assignee — confirms `.null` (not `""`) is what actually clears it,
        // matching the reference web app's own live-verified finding.
        try await cardsService.update(movedCard!, title: cardTitle, description: movedCard!.description, assigneeId: nil, assigneeName: nil)
        allCards = try await cardsService.fetchAll()
        let clearedCard = allCards.first { $0.id == createdCard.id }
        #expect(clearedCard?.assigneeId == nil, "expected assigneeId to be cleared (nil) after update with assigneeId: nil")
        #expect(clearedCard?.assigneeName == nil, "expected assigneeName to be cleared (nil) after update with assigneeName: nil")

        // --- Member attempts to create a list — expected to 403, server-enforced RBAC ---
        do {
            try await listsService.create(name: "Should never be created", position: 999, actor: memberActor)
            Issue.record("a member account was able to create a list — expected the platform to reject this with 403")
        } catch {
            let displayable = MudbaseAPIError.map(error)
            #expect(displayable.statusCode == 403, "expected member list-create to 403, got \(displayable.statusCode): \(displayable.message)")
        }

        // --- Viewer signs in: reads succeed, every write attempt 403s server-side ---
        let viewerSession = try await Self.resolveSession(authGateway: authGateway, email: Self.viewerEmail, accessEnvKey: "VIEWER_ACCESS_TOKEN", refreshEnvKey: "VIEWER_REFRESH_TOKEN")
        MudbaseSDKBootstrap.setAccessToken(viewerSession.accessToken)
        let viewer = try await authGateway.currentUser()
        #expect(viewer.role == .viewer, "expected the viewer account's customRole to resolve to .viewer, got \(String(describing: viewer.customRole))")
        let viewerActor = ActivityService.ActorInfo(actorId: viewer.id, actorName: viewer.displayName)

        let viewerLists = try await listsService.fetchAll()
        #expect(!viewerLists.isEmpty, "viewer could not read lists")
        let viewerCards = try await cardsService.fetchAll()
        #expect(viewerCards.contains { $0.id == createdCard.id }, "viewer could not read the test card")

        // Raw write attempt 1: create a card as viewer.
        do {
            try await cardsService.create(listId: targetList.id, listName: targetList.name, position: 9999, title: "Should never be created", description: nil, assigneeId: nil, assigneeName: nil, actor: viewerActor)
            Issue.record("a viewer account was able to create a card — expected the platform to reject this with 403")
        } catch {
            let displayable = MudbaseAPIError.map(error)
            #expect(displayable.statusCode == 403, "expected viewer card-create to 403, got \(displayable.statusCode): \(displayable.message)")
        }

        // Raw write attempt 2: edit the test card as viewer.
        do {
            try await cardsService.update(clearedCard!, title: "Should never be edited", description: nil, assigneeId: nil, assigneeName: nil)
            Issue.record("a viewer account was able to edit a card — expected the platform to reject this with 403")
        } catch {
            let displayable = MudbaseAPIError.map(error)
            #expect(displayable.statusCode == 403, "expected viewer card-update to 403, got \(displayable.statusCode): \(displayable.message)")
        }

        // Raw write attempt 3: delete the test card as viewer.
        do {
            try await cardsService.delete(clearedCard!, listName: targetList.name, actor: viewerActor)
            Issue.record("a viewer account was able to delete a card — expected the platform to reject this with 403")
        } catch {
            let displayable = MudbaseAPIError.map(error)
            #expect(displayable.statusCode == 403, "expected viewer card-delete to 403, got \(displayable.statusCode): \(displayable.message)")
        }

        // --- 401 refresh-and-retry: force the in-memory access token invalid, keep the real
        // refresh token in a scratch Keychain entry, and confirm `AccessTokenCoordinator`
        // transparently refreshes and retries once instead of the call failing outright. ---
        let scratchTokenStore = KeychainTokenStore(service: "dev.mudbase.showcase.kanban.manualtest")
        scratchTokenStore.save(.init(accessToken: memberSession.accessToken, refreshToken: memberSession.refreshToken))
        await AccessTokenCoordinator.shared.configure(authGateway: authGateway, tokenStore: scratchTokenStore)
        MudbaseSDKBootstrap.setAccessToken("this-access-token-is-intentionally-invalid")
        let listsAfterForcedExpiry = try await listsService.fetchAll()
        #expect(!listsAfterForcedExpiry.isEmpty, "a call made with a deliberately invalid access token did not recover via refresh-and-retry")
        scratchTokenStore.clear()

        // --- Cleanup: delete the test card (owner has full CRUD; the reference web app's own
        // build-plan documents leaving seeded demo data in place, so only this test's own
        // transient card is removed, not the pre-existing seeded board state) ---
        MudbaseSDKBootstrap.setAccessToken(ownerSession.accessToken)
        try await cardsService.delete(clearedCard!, listName: targetList.name, actor: ownerActor)
        let cardsAfterCleanup = try await cardsService.fetchAll()
        #expect(!cardsAfterCleanup.contains { $0.id == createdCard.id }, "expected the test card to be gone after cleanup")

        // --- Sign out all three accounts (best-effort) ---
        MudbaseSDKBootstrap.setAccessToken(ownerSession.accessToken)
        try? await authGateway.logout()
        MudbaseSDKBootstrap.setAccessToken(memberSession.accessToken)
        try? await authGateway.logout()
        MudbaseSDKBootstrap.setAccessToken(viewerSession.accessToken)
        try? await authGateway.logout()
    }
}
