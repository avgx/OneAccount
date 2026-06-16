import Foundation
import SSLPinning

/// Domain draft for account creation. Transient wizard state lives in
/// ``AccountCreationFlow`` and related UI-state structs.
public struct Draft: Equatable, Sendable {
    public var url: String = ""
    public var backend: Backend?
    public var user: String = ""
    public var password: String = ""
    public var displayName: String = ""
    public var session: BackendSession?

    public var serverTrustPolicy: ServerTrustPolicy = .system
    
    public init() {}

    public var resolvedEndpoint: Endpoint? {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let parsed = URL(string: trimmed) else { return nil }
        return Endpoint(url: parsed, backend: backend)
    }

    public mutating func applyDiscoveryCandidate(_ endpoint: Endpoint) {
        var components = URLComponents(url: endpoint.url, resolvingAgainstBaseURL: false)
        let userPart = components?.user
        let passwordPart = components?.password
        components?.user = nil
        components?.password = nil
        components?.fragment = nil
        guard let cleanURL = components?.url else { return }

        url = cleanURL.absoluteString
        backend = endpoint.backend

        if let userPart, let passwordPart {
            user = userPart
            password = passwordPart
        }
    }
}
