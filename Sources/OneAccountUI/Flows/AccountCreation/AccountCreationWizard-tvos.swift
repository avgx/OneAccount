#if os(tvOS)
import SwiftUI
import OneAccount

@available(tvOS 18.0, *)
@MainActor
public struct AccountCreationWizard: View {
    @ObservedObject private var flow: AccountCreationFlow
    private let suggestions: EndpointSuggestions
    @StateObject private var endpointLookup: EndpointLookup

    public init(
        flow: AccountCreationFlow,
        suggestions: EndpointSuggestions
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
