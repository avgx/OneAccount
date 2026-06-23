import Foundation
import URLKit

/// A successfully discovered server endpoint plus display name and details for lists.
public struct DiscoveryCandidate: Identifiable, Equatable, Sendable {
    public let endpoint: Endpoint
    public let name: String
    public let summary: String

    public var id: String { endpoint.id }

    public init(endpoint: Endpoint, name: String, summary: String) {
        self.endpoint = endpoint
        self.name = name
        self.summary = summary
    }

    public var rowTitle: String {
        endpoint.url.removingCredentials().pretty()
    }

    public var rowDetail: String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty { return trimmedSummary }
        if trimmedSummary.isEmpty { return trimmedName }
        return "\(trimmedName) · \(trimmedSummary)"
    }
}
