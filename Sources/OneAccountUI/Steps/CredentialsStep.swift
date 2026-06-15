import SwiftUI
import OneAccount

@MainActor
struct CredentialsStep: View {

    @Binding var draft: Draft
    @Binding var state: CredentialsState
    var onSignIn: () async throws -> Void

    var body: some View {
        Section {
            UsernameField(text: $draft.user)
                .onChange(of: draft.user) { _ in
                    resetLocalSignInState()
                }
            PasswordField(text: $draft.password)
                .onChange(of: draft.password) { _ in
                    resetLocalSignInState()
                }
        } header: {
            Text("Credentials")
        } footer: {
            if let message = state.message, !message.isEmpty {
                Text(message)
                    .foregroundStyle(.secondary)
            }
        }

        ActionButton(
            title: "Sign in",
            isLoading: state.isSigningIn,
            isDisabled: draft.user.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.password.isEmpty || state.isSigningIn
        ) {
            try await onSignIn()
        }
        .disabled(draft.user.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.password.isEmpty || state.isSigningIn)

    }

    private func resetLocalSignInState() {
        state.message = nil
        state.signInOutcomeKnown = false
        state.needsOtp = false
        state.otpCanTotp = true
    }
}
