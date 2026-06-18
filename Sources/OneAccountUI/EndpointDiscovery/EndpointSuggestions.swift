import Foundation
import URLKit

/// Host-provided URL lists for the add-account wizard endpoint step.
public struct EndpointSuggestions: Equatable, Sendable {
    /// Marketing / landing URLs (no embedded credentials).
    public var proposedURLs: [URL]
    /// Preset URLs that may include `user:password@` and `#fragment` labels.
    public var credentialSeedURLs: [URL]

    public init(proposedURLs: [URL] = [], credentialSeedURLs: [URL] = []) {
        self.proposedURLs = proposedURLs
        self.credentialSeedURLs = credentialSeedURLs
    }

}
