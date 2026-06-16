import Foundation
import SSLPinning

public struct AccountRecord: Codable, Identifiable, Sendable, Equatable, CustomStringConvertible {
    public let id: AccountID
    public var profile: Profile
    public var endpoint: Endpoint
    public var credentials: Credentials
    public var auth: AuthMethod?

    public var serverTrustPolicy: ServerTrustPolicy = .system
    
    public init(
        id: AccountID = UUID(),
        profile: Profile,
        endpoint: Endpoint,
        credentials: Credentials,
        auth: AuthMethod?,
        serverTrustPolicy: ServerTrustPolicy = .system
    ) {
        self.id = id
        self.profile = profile
        self.endpoint = endpoint
        self.credentials = credentials
        self.auth = auth
        self.serverTrustPolicy = serverTrustPolicy
    }

    /// Convenience initializer matching the previous flat layout.
    public init(
        id: AccountID = UUID(),
        baseURL: URL,
        user: String,
        password: String,
        name: String? = nil,
        backend: Backend? = nil,
        session: BackendSession? = nil,
        serverTrustPolicy: ServerTrustPolicy = .system
    ) {
        self.id = id
        self.profile = Profile(name: name)
        self.endpoint = Endpoint(url: baseURL, backend: backend)
        self.credentials = Credentials(user: user, password: password)
        if let session {
            self.auth = .bearer(session)
        } else if backend == .intl || backend == .nextLegacy {
            self.auth = .basic
        } else {
            self.auth = nil
        }
        self.serverTrustPolicy = serverTrustPolicy
    }

    public var description: String {
        "\(id) \(profile.name ?? "-") \(endpoint.backend?.rawValue ?? "?") \(credentials.user) (\(endpoint.url.absoluteString))"
    }
}

/// Read-only aliases for call sites that still speak in terms of the old flat record.
extension AccountRecord {    
    public var baseURL: URL { endpoint.url }
    public var backend: Backend? { endpoint.backend }
    public var user: String { credentials.user }
    public var password: String { credentials.password }
    public var name: String? { profile.name }

    /// Bearer session when present; `nil` for unsigned or basic-backend accounts.
    public var session: BackendSession? {
        if case .bearer(let s) = auth { return s }
        return nil
    }
}
