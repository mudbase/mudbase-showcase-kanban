import SwiftUI

/// Mirrors `../web/src/components/auth/LoginForm.tsx`. This app has no anonymous/guest session —
/// every role (including viewer) must sign in for real (see `SessionStore` doc comments), so this
/// is the only screen shown before `MainTabView`.
struct LoginView: View {
    @StateObject private var viewModel: LoginViewModel

    init(sessionStore: SessionStore) {
        _viewModel = StateObject(wrappedValue: LoginViewModel(sessionStore: sessionStore))
    }

    private static let demoPassword = "KanbanTest123!"
    // The `.test` TLD emails originally spec'd for this demo fail Mudbase's own login validation
    // live — Joi's default `email()` check excludes RFC 2606 reserved special-use TLDs. These
    // valid-domain accounts are the ones actually provisioned under the same owner/member/viewer
    // role slugs on this project — see ../web/plan/build-plan.md "Real platform finding".
    private static let demoAccounts: [(role: String, email: String)] = [
        ("Owner", "kanban.owner.demo@gmail.com"),
        ("Member", "kanban.member.demo@gmail.com"),
        ("Viewer", "kanban.viewer.demo@gmail.com"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                if let errorMessage = viewModel.errorMessage {
                    Section {
                        InlineBanner(message: errorMessage)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section("Quick sign in") {
                    ForEach(Self.demoAccounts, id: \.role) { account in
                        Button {
                            Task { await viewModel.quickFill(email: account.email, password: Self.demoPassword) }
                        } label: {
                            HStack {
                                Text(account.role)
                                Spacer()
                                Text(account.email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .disabled(viewModel.isSubmitting)
                    }
                }

                Section("Or sign in manually") {
                    TextField("Email", text: $viewModel.email)
                        .textContentType(.username)
                        .emailKeyboard()
                        .autocorrectionDisabled()
                    SecureField("Password", text: $viewModel.password)
                        .textContentType(.password)
                }

                Section {
                    Button {
                        Task { await viewModel.submit() }
                    } label: {
                        if viewModel.isSubmitting {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else {
                            Text("Sign in")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!viewModel.canSubmit)
                }
            }
            .navigationTitle("Mudbase Kanban")
        }
    }
}
