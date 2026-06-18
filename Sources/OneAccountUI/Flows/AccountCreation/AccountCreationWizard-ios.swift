#if !os(tvOS)
import SwiftUI
import OneAccount

@MainActor
public struct AccountCreationWizard: View {
    @ObservedObject private var flow: AccountCreationFlow
    private let suggestions: WizardEndpointSuggestions
    @StateObject private var endpointLookup: EndpointLookup

    public init(
        flow: AccountCreationFlow,
        suggestions: WizardEndpointSuggestions = .defaultForSample
    ) {
        self.flow = flow
        self.suggestions = suggestions
        _endpointLookup = StateObject(wrappedValue: EndpointLookup(
            validateDemoCredentials: { request in
                await flow.validateDemoCredentials(request)
            }
        ))
    }

    public var body: some View {
        Form {
            AccountCreationStepContent(
                flow: flow,
                endpointLookup: endpointLookup,
                suggestions: suggestions
            )
        }
    }
}
#endif
