import Foundation

public struct Credentials: Codable, Sendable, Equatable {
    public var user: String
    public var password: String

    public init(user: String, password: String) {
        self.user = user
        self.password = password
    }
}
