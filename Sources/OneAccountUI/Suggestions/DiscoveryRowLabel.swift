import SwiftUI
import OneAccount
import Shimmer

@MainActor
struct DiscoveryRowLabel: View {
    let title: String
    let detail: String
    let isError: Bool
    var showsCloudIcon: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3)
                .lineLimit(1)
            HStack(spacing: 4) {
                Text(detail)
                    .lineLimit(10)
                if showsCloudIcon {
                    Image(systemName: "cloud")
                }
            }
            .foregroundStyle(isError ? Color.red : Color.secondary)
            .font(.footnote)
        }
    }
}

fileprivate let previewCloud = DiscoveryCandidate(endpoint: Endpoint(url: URL(string: "https://example.com")!, backend: .cloud), summary: "some backend")

fileprivate let previewUnknownBackend = DiscoveryCandidate(endpoint: Endpoint(url: URL(string: "https://example.com")!, backend: nil), summary: "some other backend")

#Preview {
    VStack(alignment: .leading) {
        
        
        Group {
            DiscoveryRowLabel(title: previewCloud.rowTitle, detail: previewCloud.rowDetail, isError: false, showsCloudIcon: true)
            DiscoveryRowLabel(title: previewUnknownBackend.rowTitle, detail: previewUnknownBackend.rowDetail, isError: false)
            DiscoveryRowLabel(title: "https://example.com", detail: "some error", isError: true)
        }
        
        Group {
            DiscoveryRowLabel(title: "https://example.com", detail: "ok", isError: false)
        }
        .redacted(reason: .placeholder)
        .shimmering()
    }
}

