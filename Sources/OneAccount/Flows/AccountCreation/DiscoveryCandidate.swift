import Foundation
import URLKit
import OneAccount

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
}

