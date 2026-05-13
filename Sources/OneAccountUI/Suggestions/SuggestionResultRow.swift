import SwiftUI
import Shimmer
import URLKit
import OneAccount

/// Displays one discovery candidate: loading, success (backend + summary), or failure. No network — data comes from ``SuggestionLoader``.
@MainActor
struct SuggestionResultRow: View {
    let row: SuggestionLoader.Row
    var didSelect: (DiscoveryCandidate) -> Void

    var body: some View {
        Button {
            if case .succeeded(let candidate) = row.phase {
                didSelect(candidate)
            }
        } label: {
            HStack {
                switch row.phase {
                case .loading:
                    DiscoveryRowLabel(
                        title: DiscoveryCandidate.previewUnknownBackend.rowTitle,
                        detail: DiscoveryCandidate.previewUnknownBackend.rowDetail,
                        isError: false,
                        showsCloudIcon: false
                    )
                case .succeeded(let candidate):
                    DiscoveryRowLabel(
                        title: candidate.rowTitle,
                        detail: candidate.rowDetail,
                        isError: false,
                        showsCloudIcon: candidate.endpoint.backend == .cloud
                    )
                case .failed(let message):
                    DiscoveryRowLabel(
                        title: row.seedURL.removingCredentials().pretty(),
                        detail: message,
                        isError: true
                    )
                }
                Spacer()
            }
        }
        .disabled(!isSelectable)
        .redacted(reason: row.phase == .loading ? .placeholder : [])
        .shimmering(active: row.phase == .loading)
    }

    private var isSelectable: Bool {
        if case .succeeded(let candidate) = row.phase, candidate.endpoint.backend != nil { return true }
        return false
    }
}
