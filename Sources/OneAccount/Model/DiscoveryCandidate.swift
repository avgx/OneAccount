import Foundation
import URLKit

/// A successfully discovered server endpoint plus a short human summary for lists.
public struct DiscoveryCandidate: Identifiable, Equatable, Sendable {
    public let endpoint: Endpoint
    public let summary: String

    public var id: String { endpoint.id }

    public init(endpoint: Endpoint, summary: String) {
        self.endpoint = endpoint
        self.summary = summary
    }

    public var rowTitle: String {
        /*endpoint.url.fragment() ??*/ endpoint.url.removingCredentials().pretty()
    }

    public var rowDetail: String { summary }

    public static var previewCloud: DiscoveryCandidate {
        .init(endpoint: Endpoint(url: URL(string: "https://example.com")!, backend: .cloud), summary: "some backend")
    }

    public static var previewUnknownBackend: DiscoveryCandidate {
        .init(endpoint: Endpoint(url: URL(string: "https://example.com")!, backend: nil), summary: "some other backend")
    }
}

