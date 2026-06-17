import SwiftUI
import Shimmer
import OneAccount

@MainActor
struct EndpointStep: View {

    @ObservedObject var suggestionLoader: SuggestionLoader
    @Binding var state: EndpointStepState
    var suggestions: WizardEndpointSuggestions

    var onSelectRow: (DiscoveryRowSelection) -> Void
    var onConnect: () async throws -> Void
    var onURLChanged: () -> Void

    private var isInputEmpty: Bool {
        state.urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Section {
            TextField("URL of server or cloud", text: $state.urlText)
                .urlField()
                .layoutPriority(1000)
                #if os(iOS) || os(tvOS) || os(visionOS)
                .ignoresSafeArea(.keyboard, edges: .bottom)
                #endif
                .onChange(of: state.urlText) { newValue in
                    onURLChanged()
                    state.message = nil
                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty {
                        suggestionLoader.scheduleStaticReload(
                            proposedURLs: suggestions.proposedURLs,
                            demoURLs: suggestions.credentialSeedURLs
                        )
                    } else {
                        suggestionLoader.scheduleReload(rawURL: newValue)
                    }
                }
        } header: {
            EmptyView()
        } footer: {
            if let message = state.message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .onAppear {
            if isInputEmpty {
                suggestionLoader.scheduleStaticReload(
                    proposedURLs: suggestions.proposedURLs,
                    demoURLs: suggestions.credentialSeedURLs
                )
            } else {
                suggestionLoader.scheduleReload(rawURL: state.urlText)
            }
        }

        ActionButton(
            title: state.isResolving ? "connecting" : "connect",
            isLoading: state.isResolving,
            isDisabled: state.isResolving || isInputEmpty
        ) {
            #if os(iOS)
            hideKeyboard()
            #endif
            try await onConnect()
        }
        .disabled(state.isResolving || isInputEmpty)

        if isInputEmpty {
            staticSuggestions
        } else {
            discoverySuggestions
        }
    }

    @ViewBuilder
    private var discoverySuggestions: some View {
        Section {
            ForEach(suggestionLoader.rows) { row in
                SuggestionResultRow(row: row) { candidate in
                    onSelectRow(DiscoveryRowSelection(
                        candidate: candidate,
                        seedURL: row.seedURL,
                        isDemo: row.isDemo
                    ))
                }
            }
        } header: {
            HStack {
                Text("Suggestions")
                    .shimmering(active: suggestionLoader.isDiscovering && suggestionLoader.rows.isEmpty)
                Spacer()
                Button {
                    suggestionLoader.scheduleReload(rawURL: state.urlText)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .imageScale(.small)
                }
                .disabled(suggestionLoader.isDiscovering)
            }
        }
    }

    @ViewBuilder
    private var staticSuggestions: some View {
        if !suggestions.proposedURLs.isEmpty {
            Section {
                ForEach(suggestionLoader.proposedRows) { row in
                    SuggestionResultRow(row: row) { candidate in
                        onSelectRow(DiscoveryRowSelection(
                            candidate: candidate,
                            seedURL: row.seedURL,
                            isDemo: false
                        ))
                    }
                }
            } header: {
                Text("Suggestions")
                    .shimmering(active: suggestionLoader.isDiscovering && suggestionLoader.proposedRows.isEmpty)
            }
        }

        if !suggestionLoader.demoRows.isEmpty {
            Section {
                ForEach(suggestionLoader.demoRows) { row in
                    SuggestionResultRow(row: row) { candidate in
                        onSelectRow(DiscoveryRowSelection(
                            candidate: candidate,
                            seedURL: row.seedURL,
                            isDemo: true
                        ))
                    }
                }
            } header: {
                Text("Demo")
                    .shimmering(active: suggestionLoader.isDiscovering && suggestionLoader.demoRows.isEmpty)
            }
        }
    }

}
