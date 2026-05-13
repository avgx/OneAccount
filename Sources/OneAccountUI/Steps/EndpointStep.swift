import SwiftUI
import OneAccount

@MainActor
struct EndpointStep: View {

    @Binding var draft: AccountCreationDraft
    @ObservedObject var suggestionLoader: SuggestionLoader
    @Binding var state: EndpointInputState
    var suggestions: WizardEndpointSuggestions

    var onSelectSuggestion: (DiscoveryCandidate) -> Void
    var onConnect: () async throws -> Void

    var body: some View {
        Section {
            TextField("url", text: $draft.url)
                .urlField()
                .layoutPriority(1000)
                #if os(iOS) || os(tvOS) || os(visionOS)
                .ignoresSafeArea(.keyboard, edges: .bottom)
                #endif
                .onChange(of: draft.url) { newValue in
                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty {
                        draft.backend = nil
                    }
                    state.message = nil
                    suggestionLoader.scheduleReload(rawURL: newValue)
                }
        } header: {
            Text("URL of server or cloud")
        } footer: {
            if let message = state.message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }

        ActionButton(title: state.isResolving ? "connecting" : "connect", isLoading: state.isResolving) {
                hideKeyboard()
                try await onConnect()
        }
        .disabled(state.isResolving || draft.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        discoverySuggestions
        hostProposedSuggestions
        hostCredentialSuggestions
    }

    @ViewBuilder
    private var discoverySuggestions: some View {
        if !suggestionLoader.rows.isEmpty {
            Section {
                ForEach(suggestionLoader.rows) { row in
                    SuggestionResultRow(row: row) { candidate in
                        onSelectSuggestion(candidate)
                    }
                }
            } header: {
                HStack {
                    Text("Suggestions")
                    Spacer()
                    Button {
                        suggestionLoader.scheduleReload(rawURL: draft.url)
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .imageScale(.small)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var hostProposedSuggestions: some View {
        let filtered = WizardEndpointSuggestions.filter(suggestions.proposedURLs, matching: draft.url)
        if !filtered.isEmpty {
            SuggestionSection(title: "Suggestions", urls: filtered, didSelect: { candidate in
                onSelectSuggestion(candidate)
            })
        }
    }

    @ViewBuilder
    private var hostCredentialSuggestions: some View {
        let filtered = WizardEndpointSuggestions.filter(suggestions.credentialSeedURLs, matching: draft.url)
        if !filtered.isEmpty {
            SuggestionSection(title: "Demo", urls: filtered, didSelect: { candidate in
                onSelectSuggestion(candidate)
            })
        }
    }
}

