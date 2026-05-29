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
            endpointSummaryIfNeeded
            ServerCertificatesStep(
                state: flow.certificatePreviewState,
                onRetry: { await flow.reloadCertificates() },
                onContinue: {
                    flow.continueAfterCertificates()
                }
            )

        case .credentials:
            endpointSummaryIfNeeded
            CredentialsStep(
                draft: $flow.draft,
                state: $flow.credentialsState,
                onSignIn: {
                    try await flow.signIn()
                }
            )

        case .otp:
            endpointSummaryIfNeeded
            OtpStep(
                state: $flow.otpState,
                onVerify: {
                    try await flow.verifyOtp()
                }
            )

        case .done:
            endpointSummaryIfNeeded
            DoneStep(draft: $flow.draft)
        }
    }

    @ViewBuilder
    private var endpointSummaryIfNeeded: some View {
//        if flow.step != .endpoint, let endpoint = flow.draft.resolvedEndpoint {
//            Section {
//                AccountCreationSummaryRow(title: "URL", value: endpoint.url.pretty())
////                if let backend = endpoint.backend {
////                    AccountCreationSummaryRow(title: "Backend", value: backend.rawValue)
////                }
//            } header: {
//                Text("Selected server")
//            }
//            .listRowBackground(Color.clear)
//        }
        EmptyView()
    }
}

@MainActor
private struct AccountCreationSummaryRow: View {
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        FormLabeledValue(title) {
            Text(value)
#if !os(tvOS)
                .textSelection(.enabled)
#endif
        }
    }
}
