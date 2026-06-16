import SwiftUI
import OneAccount

@MainActor
struct AccountCreationStepContent: View {
    @ObservedObject var flow: AccountCreationFlow
    @ObservedObject var suggestionLoader: SuggestionLoader
    var suggestions: WizardEndpointSuggestions

    var body: some View {
        switch flow.step {
        case .endpoint:
            EndpointStep(
                draft: $flow.draft,
                suggestionLoader: suggestionLoader,
                state: $flow.endpointState,
                suggestions: suggestions,
                onSelectSuggestion: { candidate in
                    Task { await flow.selectDiscoveryCandidate(candidate) }
                },
                onConnect: {
                    try await flow.resolveEndpoint()
                }
            )
            .onDisappear { suggestionLoader.cancelPendingWork() }

        case .serverCertificates:
            ServerCertificatesStep(
                state: flow.certificatePreviewState,
                policy: $flow.draft.serverTrustPolicy,
                onRetry: { await flow.reloadCertificates() },
                onContinue: {
                    flow.continueAfterCertificates()
                }
            )

        case .credentials:
            CredentialsStep(
                draft: $flow.draft,
                state: $flow.credentialsState,
                onSignIn: {
                    try await flow.signIn()
                }
            )

        case .otp:
            OtpStep(
                state: $flow.otpState,
                onVerify: {
                    try await flow.verifyOtp()
                }
            )

        case .done:
            DoneStep(draft: $flow.draft)
        }
    }

}
