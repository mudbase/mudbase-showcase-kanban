import Foundation

/// Mirrors `../web/src/hooks/useActivity.ts` + `../web/src/app/activity/page.tsx`. There is no
/// official Mudbase realtime client outside JavaScript (see `BoardViewModel`'s doc comment for the
/// same reasoning) — this polls the feed every `pollInterval` while `ActivityView` is on screen
/// instead of subscribing to the web app's Socket.IO `activity` room.
@MainActor
final class ActivityViewModel: ObservableObject {
    @Published private(set) var entries: [ActivityEntry] = []
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?

    private let activityService: ActivityService
    private var pollTask: Task<Void, Never>?
    private static let pollInterval: Duration = .seconds(5)

    init(config: AppConfig) {
        activityService = ActivityService(config: config)
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
            entries = try await activityService.feed()
            errorMessage = nil
        } catch {
            errorMessage = MudbaseAPIError.map(error).message
        }
    }
}
