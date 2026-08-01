import SwiftUI

/// One card cell within a `ListColumnView`. Mirrors `../web/src/components/board/CardItem.tsx`,
/// with the "move up"/"move down"/"Move to…" controls from
/// `../web/src/components/board/MoveCardControl.tsx` folded in directly — this is a deliberate,
/// dependency-light choice ported from the reference web app: button/menu-based movement instead
/// of a drag gesture, fully accessible with VoiceOver with zero extra work (see
/// `../web/plan/build-plan.md` "Stack Decisions").
struct CardRowView: View {
    let card: BoardCard
    let list: BoardList
    let otherLists: [BoardList]
    let prevCard: BoardCard?
    let nextCard: BoardCard?
    let canManage: Bool
    @ObservedObject var viewModel: BoardViewModel
    var onEdit: () -> Void

    @State private var confirmDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text(card.title)
                    .font(.subheadline.weight(.medium))
                Spacer()
                if canManage {
                    Menu {
                        Button("Edit", systemImage: "pencil", action: onEdit)
                        Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = true }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let description = card.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            if let assigneeName = card.assigneeName, !assigneeName.isEmpty {
                HStack(spacing: 6) {
                    AvatarView(name: assigneeName, size: 20)
                    Text(assigneeName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if confirmDelete {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Delete this card?").font(.caption2)
                    HStack {
                        Button("Delete", role: .destructive) {
                            confirmDelete = false
                            Task { await viewModel.deleteCard(card, in: list) }
                        }
                        Button("Cancel") { confirmDelete = false }
                    }
                }
                .padding(6)
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            if canManage {
                HStack(spacing: 6) {
                    Button {
                        if let prevCard {
                            Task { await viewModel.reorderCard(card, with: prevCard, in: list) }
                        }
                    } label: {
                        Image(systemName: "chevron.up")
                    }
                    .disabled(prevCard == nil)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityLabel("Move up")

                    Button {
                        if let nextCard {
                            Task { await viewModel.reorderCard(card, with: nextCard, in: list) }
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .disabled(nextCard == nil)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityLabel("Move down")

                    if !otherLists.isEmpty {
                        Menu {
                            ForEach(otherLists) { target in
                                Button(target.name) {
                                    Task { await viewModel.moveCard(card, from: list, to: target) }
                                }
                            }
                        } label: {
                            Label("Move to…", systemImage: "arrowshape.turn.up.right")
                                .font(.caption2)
                        }
                        .controlSize(.small)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.separator))
    }
}
