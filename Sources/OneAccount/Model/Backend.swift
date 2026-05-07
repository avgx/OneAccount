import Foundation

/// Backend type
public enum Backend: String, Codable, Equatable, Sendable {
    /// Cloud with access / refresh (needs session with long living tokens with refresh by refreshToken)
    case cloud
    /// Next with bearer auth (needs session with short living token with refresh by valid token)
    case next
    /// Legacy Next basic auth (no session, just user:password)
    case nextLegacy
    /// Intl4 basic auth (no session, just user:password)
    case intl
}
