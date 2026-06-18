import SwiftUI
import OneAccount

@MainActor
struct AccountCreationStepContent: View {
    @ObservedObject var flow: AccountCreationFlow
    @ObservedObject var endpointLookup: EndpointLookup
    var suggestions: EndpointSuggestions

    var body: some View {
        switch flow.step {
        case .endpoint:
            EndpointStep(
                endpointLookup: endpointLookup,
                state: $flow.endpointState,
                suggestions: suggestions,
                onSelectRow: { selection in
                    Task { await flow.selectDiscoveryRow(selection) }
                },
                onLookUp: {
                    await endpointLookup.reloadNow(rawURL: flow.endpointState.urlText)
                },
                onURLChanged: {
                    flow.clearResolvedEndpointOnURLChange()
                }
            )
            .onDisappear { endpointLookup.cancelPendingWork() }

        case .serverCertificates:
            ServerCertificatesStep(
                preview: flow.certificatePreview,
                host: flow.draft.resolvedEndpoint?.url.host ?? "",
                policy: $flow.draft.serverTrustPolicy,
                onReload: { probePolicy in
                    await flow.reloadCertificates(probePolicy: probePolicy)
                },
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
            DoneStep(
                draft: $flow.draft,
                canSave: flow.canSave,
                isSaving: flow.isSavingAccount,
                onSave: {
                    guard let performSave = flow.performSave else { return }
                    try await performSave()
                }
            )
        }
    }

}
