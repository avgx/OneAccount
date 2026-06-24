import SwiftUI
import OneAccount

@MainActor
struct EndpointStep: View {

    @ObservedObject var endpointLookup: EndpointLookup
    @Binding var state: EndpointStepState
    var suggestions: EndpointSuggestions

    var onSelectRow: (DiscoveryRowSelection) -> Void
    var onLookUp: () async -> Void
    var onURLChanged: () -> Void

    private var isInputEmpty: Bool {
        state.urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var lookUpButtonTitle: LocalizedStringKey {
//        if endpointLookup.isDiscovering {
//            return "Looking up"
//        }
        if endpointLookup.canRetry(for: state.urlText) {
            return "Retry"
        }
        return "Look up"
    }

    var body: some View {
        Section {
            TextField("URL of server or cloud", text: $state.urlText)
                .urlField()
                #if os(iOS)
                .submitLabel(.search)
                #endif
                .layoutPriority(1000)
                #if os(iOS) || os(tvOS) || os(visionOS)
                .ignoresSafeArea(.keyboard, edges: .bottom)
                #endif
                .onSubmit {
                    Task { await performLookUp() }
                }
                .onChange(of: state.urlText) { newValue in
                    onURLChanged()
                    state.message = nil
                    endpointLookup.clearExploredInput()
                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty {
                        endpointLookup.scheduleStaticReload(
                            proposedURLs: suggestions.proposedURLs,
                            demoURLs: suggestions.credentialSeedURLs
                        )
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
                endpointLookup.scheduleStaticReload(
                    proposedURLs: suggestions.proposedURLs,
                    demoURLs: suggestions.credentialSeedURLs
                )
            }
        }

        ActionButton(
            title: lookUpButtonTitle,
            isDisabled: endpointLookup.isDiscovering || isInputEmpty,
            action: performLookUp
        )

        if isInputEmpty {
            staticPresets
        } else {
            foundEndpoints
        }
    }

    private func performLookUp() async {
        #if os(iOS)
        hideKeyboard()
        #endif
        await onLookUp()
    }

    @ViewBuilder
    private var foundEndpoints: some View {
        Section {
            ForEach(endpointLookup.rows) { row in
                ResolvedEndpointRow(row: row) { candidate in
                    onSelectRow(DiscoveryRowSelection(
                        candidate: candidate,
                        seedURL: row.seedURL,
                        isDemo: row.isDemo
                    ))
                }
            }
        }
    }

    @ViewBuilder
    private var staticPresets: some View {
        if !suggestions.proposedURLs.isEmpty {
            Section {
                ForEach(endpointLookup.proposedRows) { row in
                    ResolvedEndpointRow(row: row) { candidate in
                        onSelectRow(DiscoveryRowSelection(
                            candidate: candidate,
                            seedURL: row.seedURL,
                            isDemo: false
                        ))
                    }
                }
            }
        }

        if !endpointLookup.demoRows.isEmpty {
            Section {
                ForEach(endpointLookup.demoRows) { row in
                    ResolvedEndpointRow(row: row) { candidate in
                        onSelectRow(DiscoveryRowSelection(
                            candidate: candidate,
                            seedURL: row.seedURL,
                            isDemo: true
                        ))
                    }
                }
            }
        }
    }

}
