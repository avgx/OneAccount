import Foundation

public struct AccountCredentialsRequest: Equatable, Sendable {
    public var endpoint: Endpoint
    public var user: String
    public var password: String

    public init(endpoint: Endpoint, user: String, password: String) {
        self.endpoint = endpoint
        self.user = user
        self.password = password
    }
}
