import SwiftUI

/// Create-or-edit modal for a card. Mirrors `../web/src/components/board/CardDialog.tsx` — which
/// mode it's in is determined by whether `existingCard` is present; both modes share the same
/// form and validation limits (title 120 chars, description 2000, assignee name 80).
struct CardFormView: View {
    let list: BoardList
    let existingCard: BoardCard?
    @ObservedObject var viewModel: BoardViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var description: String
    @State private var assigneeName: String
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private static let titleLimit = 120
    private static let descriptionLimit = 2000
    private static let assigneeLimit = 80

    init(list: BoardList, existingCard: BoardCard?, viewModel: BoardViewModel) {
        self.list = list
        self.existingCard = existingCard
        self.viewModel = viewModel
        _title = State(initialValue: existingCard?.title ?? "")
        _description = State(initialValue: existingCard?.description ?? "")
        _assigneeName = State(initialValue: existingCard?.assigneeName ?? "")
    }

    private var isEditing: Bool { existingCard != nil }

    private var titleValidationMessage: String? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Title is required" }
        if trimmed.count > Self.titleLimit { return "Keep the title under \(Self.titleLimit) characters" }
        return nil
    }

    private var canSubmit: Bool {
        !isSubmitting
            && titleValidationMessage == nil
            && description.count <= Self.descriptionLimit
            && assigneeName.count <= Self.assigneeLimit
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("e.g. Write onboarding docs", text: $title)
                    if let titleValidationMessage, !title.isEmpty {
                        Text(titleValidationMessage).font(.caption).foregroundStyle(.red)
                    }
                }

                Section("Description (optional)") {
                    TextEditor(text: $description)
                        .frame(minHeight: 100)
                    if description.count > Self.descriptionLimit {
                        Text("Keep the description under \(Self.descriptionLimit) characters")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section("Assignee (optional)") {
                    TextField("e.g. Ben Chen", text: $assigneeName)
                    if assigneeName.count > Self.assigneeLimit {
                        Text("Keep the assignee name under \(Self.assigneeLimit) characters")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).font(.caption).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit card" : "New card in \(list.name)")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSubmitting ? "Saving…" : (isEditing ? "Save" : "Create"), action: submit)
                        .disabled(!canSubmit)
                }
            }
        }
    }

    private func submit() {
        guard canSubmit else { return }
        isSubmitting = true
        errorMessage = nil

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAssignee = assigneeName.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            if let existingCard {
                await viewModel.updateCard(
                    existingCard,
                    title: trimmedTitle,
                    description: trimmedDescription.isEmpty ? nil : trimmedDescription,
                    assigneeName: trimmedAssignee.isEmpty ? nil : trimmedAssignee
                )
            } else {
                await viewModel.createCard(
                    in: list,
                    title: trimmedTitle,
                    description: trimmedDescription.isEmpty ? nil : trimmedDescription,
                    assigneeName: trimmedAssignee.isEmpty ? nil : trimmedAssignee
                )
            }
            isSubmitting = false
            if let actionError = viewModel.actionErrorMessage {
                errorMessage = actionError
                viewModel.actionErrorMessage = nil
            } else {
                dismiss()
            }
        }
    }
}
