import SwiftUI

/// Owner-only column at the end of the board row for adding a new list. Mirrors
/// `../web/src/components/board/AddListForm.tsx`.
struct AddListColumnView: View {
    @ObservedObject var viewModel: BoardViewModel

    @State private var isOpen = false
    @State private var name = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false

    private static let nameLimit = 60

    var body: some View {
        Group {
            if isOpen {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("List name", text: $name)
                        .textFieldStyle(.roundedBorder)
                    if let errorMessage {
                        Text(errorMessage).font(.caption).foregroundStyle(.red)
                    }
                    HStack {
                        Button(isSubmitting ? "Adding…" : "Add list", action: submit)
                            .disabled(isSubmitting)
                        Button("Cancel") {
                            isOpen = false
                            name = ""
                            errorMessage = nil
                        }
                    }
                }
                .padding()
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
            } else {
                Button {
                    isOpen = true
                } label: {
                    Label("Add list", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(width: 260)
    }

    private func submit() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Name is required"
            return
        }
        guard trimmed.count <= Self.nameLimit else {
            errorMessage = "Keep the name under \(Self.nameLimit) characters"
            return
        }
        errorMessage = nil
        isSubmitting = true
        Task {
            let success = await viewModel.createList(name: trimmed)
            isSubmitting = false
            if success {
                name = ""
                isOpen = false
            }
        }
    }
}
