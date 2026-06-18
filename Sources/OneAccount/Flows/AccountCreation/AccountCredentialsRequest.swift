import Foundation
import SSLPinning

public struct AccountCredentialsRequest: Equatable, Sendable {
    public var endpoint: Endpoint
    public var user: String
    public var password: String
    public var serverTrustPolicy: ServerTrustPolicy

    public init(
        endpoint: Endpoint,
        user: String,
        password: String,
        serverTrustPolicy: ServerTrustPolicy = .system
    ) {
        self.endpoint = endpoint
        self.user = user
        self.password = password
        self.serverTrustPolicy = serverTrustPolicy
    }
}
