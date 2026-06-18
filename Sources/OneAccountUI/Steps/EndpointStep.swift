import SwiftUI
import Shimmer
import OneAccount

@MainActor
struct EndpointStep: View {

    @ObservedObject var endpointLookup: EndpointLookup
    @Binding var state: EndpointStepState
    var suggestions: WizardEndpointSuggestions

    var onSelectRow: (DiscoveryRowSelection) -> Void
    var onLookUp: () async -> Void
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
                        endpointLookup.scheduleStaticReload(
                            proposedURLs: suggestions.proposedURLs,
                            demoURLs: suggestions.credentialSeedURLs
                        )
                    } else {
                        endpointLookup.scheduleReload(rawURL: newValue)
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
            } else {
                endpointLookup.scheduleReload(rawURL: state.urlText)
            }
        }

        ActionButton(
            title: endpointLookup.isDiscovering ? "lookingUp" : "lookUp",
            isLoading: endpointLookup.isDiscovering,
            isDisabled: endpointLookup.isDiscovering || isInputEmpty
        ) {
            #if os(iOS)
            hideKeyboard()
            #endif
            await onLookUp()
        }
        .disabled(endpointLookup.isDiscovering || isInputEmpty)

        if isInputEmpty {
            staticPresets
        } else {
            foundEndpoints
        }
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
        } header: {
            HStack {
                Text("Found")
                    .shimmering(active: endpointLookup.isDiscovering && endpointLookup.rows.isEmpty)
                Spacer()
                Button {
                    Task {
                        await endpointLookup.reloadNow(rawURL: state.urlText)
                    }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .imageScale(.small)
                }
                .disabled(endpointLookup.isDiscovering)
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
            } header: {
                Text("Available")
                    .shimmering(active: endpointLookup.isDiscovering && endpointLookup.proposedRows.isEmpty)
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
            } header: {
                Text("Demo")
                    .shimmering(active: endpointLookup.isDiscovering && endpointLookup.demoRows.isEmpty)
            }
        }
    }

}
