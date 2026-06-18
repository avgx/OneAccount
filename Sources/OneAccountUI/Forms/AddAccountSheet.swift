import SwiftUI
import OneAccount
import SSLPinning
import DebugThings

fileprivate func resolveEndpoint(_ input: String) async throws -> ResolvedEndpoint {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    let result = try await WizardEndpointDiscovery.resolveEndpoint(trimmedURL: trimmed)
    return ResolvedEndpoint(url: result.url, backend: result.backend)
}

public struct AddAccountSheet<WizardContent: View>: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var flow: AccountCreationFlow
    @State private var saveInFlight = false

    private let content: (AccountCreationFlow) -> WizardContent
    public let onSave: (Draft) -> Void

    
    
    public init(
        endpointWizardMode: EndpointWizardMode = .free,
        clientId: String,
        logger: (any URLSessionTaskLogger)? = nil,
        onSave: @escaping (Draft) -> Void,
        @ViewBuilder content: @escaping (AccountCreationFlow) -> WizardContent
    ) {
        self.onSave = onSave
        self.content = content
        let auth = AuthService(clientId: clientId, logger: logger) { _ in
            throw AuthServiceError.unsupportedBackend
        }
        _flow = StateObject(
            wrappedValue: AccountCreationFlow(
                mode: endpointWizardMode,
                useCases: AccountCreationUseCases(
                    authService: auth,
                    resolveEndpoint: resolveEndpoint
                )
            )
        )
    }

    public init(
        endpointWizardMode: EndpointWizardMode = .free,
        serverTrustPolicy: ServerTrustPolicy = .system,
        clientId: String,
        logger: (any URLSessionTaskLogger)? = nil,
        suggestions: EndpointSuggestions,
        onSave: @escaping (Draft) -> Void
    ) where WizardContent == AccountCreationWizard {
        self.init(
            endpointWizardMode: endpointWizardMode,
            clientId: clientId,
            logger: logger,
            onSave: onSave
        ) { flow in
            AccountCreationWizard(flow: flow, suggestions: suggestions)
        }
    }

    public var body: some View {
        content(flow)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .navigationTitle("")
            .background {
                WizardSaveWiring(flow: flow, saveInFlight: $saveInFlight, onSave: onSave)
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    wizardToolbarTitle
                }
            }
    }

    @ViewBuilder
    private var wizardToolbarTitle: some View {
        if flow.isEndpointLocked {
            Text("Add Account")
                .font(.headline)
                .lineLimit(1)
        } else {
            VStack(spacing: 4) {
                if flow.step != .endpoint, let endpoint = flow.draft.resolvedEndpoint {
                    HStack(spacing: 4) {
                        Image(systemName: endpoint.backend.icon)
                        Text(endpoint.url.pretty())
                    }
                } else {
                    Text("Add Account")
                        .font(.headline)
                        .lineLimit(1)
                }

                WizardStepHeader(
                    current: flow.wizardCurrentStepIndex,
                    total: flow.wizardTotalSteps
                )
            }
            .accessibilityElement(children: .combine)
        }
    }
}

@MainActor
private struct WizardSaveWiring: View {
    @ObservedObject var flow: AccountCreationFlow
    @Binding var saveInFlight: Bool
    let onSave: (Draft) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear { wireSaveHandler() }
            .onChange(of: flow.step) { _ in wireSaveHandler() }
    }

    private func wireSaveHandler() {
        flow.performSave = {
            guard flow.canSave, !saveInFlight else { return }
            saveInFlight = true
            flow.isSavingAccount = true
            defer {
                saveInFlight = false
                flow.isSavingAccount = false
            }
            flow.prepareDraftForSave()
            onSave(flow.draft)
            dismiss()
        }
    }
}
