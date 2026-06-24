import SwiftUI
import OneAccount
import SSLPinning
import DebugThings

public struct AddAccountWizard<WizardContent: View>: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var flow: AccountCreationFlow
    @State private var saveInFlight = false

    private let content: (AccountCreationFlow) -> WizardContent
    public let onSave: (Draft) -> Void

    public init(
        endpointWizardMode: EndpointWizardMode = .free,
        discovery: DiscoveryClient? = nil,
        clientId: String,
        logger: (any URLSessionTaskLogger)? = nil,
        onSave: @escaping (Draft) -> Void,
        @ViewBuilder content: @escaping (AccountCreationFlow) -> WizardContent
    ) {
        if case .free = endpointWizardMode {
            precondition(discovery != nil, "discovery is required when endpointWizardMode is .free")
        }

        self.onSave = onSave
        self.content = content
        let auth = AuthService(clientId: clientId, logger: logger) { _ in
            throw AuthServiceError.unsupportedBackend
        }
        _flow = StateObject(
            wrappedValue: AccountCreationFlow(
                mode: endpointWizardMode,
                useCases: AccountCreationUseCases(authService: auth)
            )
        )
    }

    public init(
        endpointWizardMode: EndpointWizardMode = .free,
        discovery: DiscoveryClient? = nil,
        serverTrustPolicy: ServerTrustPolicy = .system,
        clientId: String,
        logger: (any URLSessionTaskLogger)? = nil,
        suggestions: EndpointSuggestions,
        onSave: @escaping (Draft) -> Void
    ) where WizardContent == AccountCreationWizard {
        self.init(
            endpointWizardMode: endpointWizardMode,
            discovery: discovery,
            clientId: clientId,
            logger: logger,
            onSave: onSave
        ) { flow in
            AccountCreationWizard(flow: flow, discovery: discovery, suggestions: suggestions)
        }
    }

    public var body: some View {
        content(flow)
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
            Text("add-account", bundle: .module)
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
                    Text("add-account", bundle: .module)
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
            defer { saveInFlight = false }
            flow.prepareDraftForSave()
            onSave(flow.draft)
            dismiss()
        }
    }
}
