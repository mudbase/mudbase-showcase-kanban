import SwiftUI

/// One board column. Mirrors `../web/src/components/board/ListColumn.tsx`.
struct ListColumnView: View {
    let list: BoardList
    let cards: [BoardCard]
    let otherLists: [BoardList]
    let prevList: BoardList?
    let nextList: BoardList?
    let canManageLists: Bool
    let canManageCards: Bool
    @ObservedObject var viewModel: BoardViewModel

    @State private var isRenaming = false
    @State private var draftName = ""
    @State private var renameError: String?
    @State private var confirmDelete = false
    @State private var isCreatingCard = false
    @State private var editingCard: BoardCard?

    private static let nameLimit = 60

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if confirmDelete {
                deleteConfirmation
            }

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                        CardRowView(
                            card: card,
                            list: list,
                            otherLists: otherLists,
                            prevCard: index > 0 ? cards[index - 1] : nil,
                            nextCard: index < cards.count - 1 ? cards[index + 1] : nil,
                            canManage: canManageCards,
                            viewModel: viewModel,
                            onEdit: { editingCard = card }
                        )
                    }
                    if cards.isEmpty {
                        Text("No cards yet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 12)
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 480)

            if canManageCards {
                Divider()
                Button {
                    isCreatingCard = true
                } label: {
                    Label("Add card", systemImage: "plus")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(8)
            }
        }
        .frame(width: 280)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.separator))
        .sheet(isPresented: $isCreatingCard) {
            CardFormView(list: list, existingCard: nil, viewModel: viewModel)
        }
        .sheet(item: $editingCard) { card in
            CardFormView(list: list, existingCard: card, viewModel: viewModel)
        }
    }

    private var header: some View {
        Group {
            if isRenaming {
                renameField
            } else {
                HStack {
                    Text(list.name).font(.headline).lineLimit(1)
                    Text("(\(cards.count))").font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    if canManageLists {
                        listMenu
                    }
                }
            }
        }
        .padding(12)
    }

    private var renameField: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                TextField("List name", text: $draftName)
                    .textFieldStyle(.roundedBorder)
                Button("Save", action: saveRename)
                Button("Cancel") { isRenaming = false }
            }
            if let renameError {
                Text(renameError).font(.caption2).foregroundStyle(.red)
            }
        }
    }

    private var listMenu: some View {
        Menu {
            Button("Move left", systemImage: "arrow.left") {
                Task { await viewModel.moveList(list, toward: prevList) }
            }
            .disabled(prevList == nil)

            Button("Move right", systemImage: "arrow.right") {
                Task { await viewModel.moveList(list, toward: nextList) }
            }
            .disabled(nextList == nil)

            Button("Rename", systemImage: "pencil") {
                draftName = list.name
                renameError = nil
                isRenaming = true
            }

            Button("Delete", systemImage: "trash", role: .destructive) {
                confirmDelete = true
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    private var deleteConfirmation: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(cards.isEmpty ? "Delete \"\(list.name)\"?" : "Delete \"\(list.name)\" and its \(cards.count) card(s)?")
                .font(.caption)
            HStack {
                Button("Delete", role: .destructive) {
                    confirmDelete = false
                    Task { await viewModel.deleteList(list) }
                }
                Button("Cancel") { confirmDelete = false }
            }
        }
        .padding(8)
        .background(Color.red.opacity(0.08))
    }

    private func saveRename() {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            renameError = "Name is required"
            return
        }
        guard trimmed.count <= Self.nameLimit else {
            renameError = "Keep the name under \(Self.nameLimit) characters"
            return
        }
        if trimmed == list.name {
            isRenaming = false
            return
        }
        renameError = nil
        Task {
            let success = await viewModel.renameList(list, to: trimmed)
            if success { isRenaming = false }
        }
    }
}
