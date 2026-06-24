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
            Text("credentials", bundle: .module)
        } footer: {
            if let failure = state.failure {
                Text(UserFacingErrorMessage.text(for: failure))
                    .foregroundStyle(.secondary)
            }
        }

        ActionButton(
            title: "sign-in",
            isDisabled: draft.user.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.password.isEmpty,
            action: onSignIn
        )
    }

    private func resetLocalSignInState() {
        state.failure = nil
        state.signInOutcomeKnown = false
        state.needsOtp = false
        state.otpCanTotp = true
    }
}
