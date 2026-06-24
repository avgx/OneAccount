import Foundation
import SSLPinning

/// Domain draft for account creation. Transient wizard state lives in
/// ``AccountCreationFlow`` and related UI-state structs.
public struct Draft: Equatable, Sendable {
    public var resolvedEndpoint: ResolvedEndpoint?
    public var user: String = ""
    public var password: String = ""
    public var displayName: String = ""
    public var session: BackendSession?

    public var serverTrustPolicy: ServerTrustPolicy = .system

    public init() {}
    
    public var defaultName: String {
        guard let resolvedEndpoint, !user.isEmpty else { return "" }
        return resolvedEndpoint.backend == .cloud ? user : "\(user)@\(resolvedEndpoint.url.pretty())"
    }
}

extension ResolvedEndpoint {
    /// ``Endpoint`` view for APIs that still take optional backend.
    public var asEndpoint: Endpoint {
        Endpoint(url: url, backend: backend)
    }
}
