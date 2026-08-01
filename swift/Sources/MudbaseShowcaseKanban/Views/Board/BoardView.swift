import SwiftUI

/// The board screen: a horizontally-scrolling row of `ListColumnView`s plus an owner-only
/// "Add list" affordance at the end. Mirrors `../web/src/components/board/BoardView.tsx`.
struct BoardView: View {
    let config: AppConfig
    let currentUser: AppUser
    @StateObject private var viewModel: BoardViewModel
    @EnvironmentObject private var sessionStore: SessionStore

    init(config: AppConfig, currentUser: AppUser) {
        self.config = config
        self.currentUser = currentUser
        _viewModel = StateObject(wrappedValue: BoardViewModel(config: config, currentUser: currentUser))
    }

    private var role: AppRole? { currentUser.role }

    var body: some View {
        VStack(spacing: 0) {
            if isReadOnly(role) {
                InlineBanner(message: "Read-only — you're signed in as \(roleLabel(role))", isDestructive: false)
                    .padding([.horizontal, .top])
            }

            Group {
                if viewModel.isLoading {
                    LoadingView()
                } else if let errorMessage = viewModel.loadErrorMessage {
                    InlineErrorView(message: errorMessage) {
                        Task { await viewModel.refresh() }
                    }
                } else {
                    boardScroll
                }
            }
        }
        .navigationTitle("Team Board")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Text("\(currentUser.displayName) · \(roleLabel(role))")
                    Button("Sign out", role: .destructive) {
                        Task { await sessionStore.logout() }
                    }
                } label: {
                    Image(systemName: "person.crop.circle")
                }
            }
        }
        .task { await viewModel.start() }
        .onDisappear { viewModel.stopPolling() }
        .alert("Something went wrong", isPresented: actionErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.actionErrorMessage ?? "")
        }
    }

    private var actionErrorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.actionErrorMessage != nil },
            set: { isPresented in if !isPresented { viewModel.actionErrorMessage = nil } }
        )
    }

    private var boardScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(Array(viewModel.lists.enumerated()), id: \.element.id) { index, list in
                    ListColumnView(
                        list: list,
                        cards: viewModel.cards(in: list),
                        otherLists: viewModel.otherLists(than: list),
                        prevList: index > 0 ? viewModel.lists[index - 1] : nil,
                        nextList: index < viewModel.lists.count - 1 ? viewModel.lists[index + 1] : nil,
                        canManageLists: canManageLists(role),
                        canManageCards: canManageCards(role),
                        viewModel: viewModel
                    )
                }

                if canManageLists(role) {
                    AddListColumnView(viewModel: viewModel)
                } else if viewModel.lists.isEmpty {
                    EmptyStateView(message: "The board has no lists yet.")
                        .frame(width: 260)
                }
            }
            .padding()
        }
    }
}
