#if !os(tvOS)
import SwiftUI
import OneAccount

@MainActor
public struct AccountCreationWizard: View {
    @ObservedObject private var flow: AccountCreationFlow
    private let suggestions: WizardEndpointSuggestions
    @StateObject private var suggestionLoader = SuggestionLoader()

    public init(
        flow: AccountCreationFlow,
        suggestions: WizardEndpointSuggestions = .defaultForSample
    ) {
        self.flow = flow
        self.suggestions = suggestions
    }

    public var body: some View {
        Form {
            AccountCreationStepContent(
                flow: flow,
                suggestionLoader: suggestionLoader,
                suggestions: suggestions
            )
        }
    }
}
#endif
