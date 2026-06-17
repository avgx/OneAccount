import SwiftUI
import OneAccount

/// Displays one discovered endpoint candidate.
@MainActor
struct SuggestionResultRow: View {
    let row: SuggestionLoader.Row
    var didSelect: (DiscoveryCandidate) -> Void

    var body: some View {
        Button {
            didSelect(row.candidate)
        } label: {
            HStack {
                DiscoveryRowLabel(
                    title: row.candidate.rowTitle,
                    detail: row.candidate.rowDetail,
                    isError: false,
                    showsCloudIcon: row.candidate.endpoint.backend == .cloud
                )
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}
