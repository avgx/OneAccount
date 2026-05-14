import SwiftUI
import OneAccount
import SSLPinning
import DebugThings

public struct AddAccountSheet<WizardContent: View>: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var flow: AccountCreationFlow
    @State private var saveInFlight = false

    private let content: (AccountCreationFlow) -> WizardContent
    public let onSave: (AccountCreationDraft) -> Void

    public init(
        endpointWizardMode: EndpointWizardMode = .free,
        serverTrustPolicy: ServerTrustPolicy = .system,
        clientId: String,
        logger: (any URLSessionTaskLogger)? = nil,
        onSave: @escaping (AccountCreationDraft) -> Void,
        @ViewBuilder content: @escaping (AccountCreationFlow) -> WizardContent
    ) {
        self.onSave = onSave
        self.content = content
        let auth = AuthService(clientId: clientId) { _ in
            throw AuthServiceError.unsupportedBackend
        }
        _flow = StateObject(
            wrappedValue: AccountCreationFlow(
                mode: endpointWizardMode,
                useCases: AccountCreationUseCases(
                    authService: auth,
                    serverTrustPolicy: serverTrustPolicy,
                    logger: logger
                )
            )
        )
    }

    public init(
        endpointWizardMode: EndpointWizardMode = .free,
        serverTrustPolicy: ServerTrustPolicy = .system,
        clientId: String,
        logger: (any URLSessionTaskLogger)? = nil,
        suggestions: WizardEndpointSuggestions = .defaultForSample,
        onSave: @escaping (AccountCreationDraft) -> Void
    ) where WizardContent == AccountCreationWizardLegacy {
        self.init(
            endpointWizardMode: endpointWizardMode,
            serverTrustPolicy: serverTrustPolicy,
            clientId: clientId,
            logger: logger,
            onSave: onSave
        ) { flow in
            AccountCreationWizardLegacy(flow: flow, suggestions: suggestions)
        }
    }

    public var body: some View {
        content(flow)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    wizardToolbarTitle
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: confirmSave) {
                        Group {
                            if saveInFlight {
                                ProgressView()
                            } else {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!flow.canSave || saveInFlight)
                }
            }
    }

    private var wizardToolbarTitle: some View {
        VStack(spacing: 4) {
            Text("Add Account")
                .font(.headline)
                .lineLimit(1)
            WizardStepHeader(
                current: flow.wizardCurrentStepIndex,
                total: flow.wizardTotalSteps,
                compact: true
            )
        }
        .accessibilityElement(children: .combine)
    }

    @MainActor
    private func confirmSave() {
        guard flow.canSave, !saveInFlight else { return }
        saveInFlight = true
        onSave(flow.draft)
        saveInFlight = false
        dismiss()
    }
}

#Preview("Legacy free endpoint") {
    if #available(iOS 16.0, tvOS 16.0, *) {
        NavigationStack {
            AddAccountSheet(clientId: UUID().uuidString) { draft in
                print("add \(draft.url)")
            }
        }
    } else {
        Text("Not available")
    }
}

#Preview("Legacy locked URL") {
    if #available(iOS 16.0, tvOS 16.0, *) {
        NavigationStack {
            AddAccountSheet(
                endpointWizardMode: EndpointWizardMode.locked(
                    Endpoint(url: URL(string: "https://axxonnet.com")!, backend: .cloud)
                ),
                clientId: UUID().uuidString
            ) { draft in
                print("add locked \(draft.url)")
            }
        }
    } else {
        Text("Not available")
    }
}

#if os(iOS)
@available(iOS 18.0, tvOS 18.0, *)
#Preview("iOS 18 explicit wizard") {
    NavigationStack {
        AddAccountSheet(
            clientId: UUID().uuidString,
            onSave: { draft in
                print("add ios18 \(draft.url)")
            }
        ) { flow in
            AccountCreationWizardIOS18(flow: flow)
        }
    }
}
#endif
