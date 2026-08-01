import SwiftUI

/// Full reverse-chronological activity feed. Mirrors `../web/src/app/activity/page.tsx` +
/// `../web/src/components/activity/ActivityFeed.tsx`.
struct ActivityView: View {
    let config: AppConfig
    @StateObject private var viewModel: ActivityViewModel

    init(config: AppConfig) {
        self.config = config
        _viewModel = StateObject(wrappedValue: ActivityViewModel(config: config))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingView()
            } else if let errorMessage = viewModel.errorMessage {
                InlineErrorView(message: errorMessage) {
                    Task { await viewModel.refresh() }
                }
            } else if viewModel.entries.isEmpty {
                EmptyStateView(message: "No activity yet.")
            } else {
                List(viewModel.entries) { entry in
                    ActivityRowView(entry: entry)
                }
                .listStyle(.plain)
                .refreshable { await viewModel.refresh() }
            }
        }
        .navigationTitle("Activity")
        .task { await viewModel.start() }
        .onDisappear { viewModel.stopPolling() }
    }
}
