import Foundation
import JWTDecode

public struct NextSession: Codable, Sendable, Equatable {
    public let authToken: String
    private let cachedExp: Date?

    public init(authToken: String) {
        self.authToken = authToken
        self.cachedExp = (try? decode(jwt: authToken))?.expiresAt
    }

    public var accessExpiresAt: Date? {
        cachedExp
    }
    
    public func shouldRefresh(margin: TimeInterval) -> Bool {
        guard let exp = accessExpiresAt else { return false }
        return exp.timeIntervalSinceNow <= margin
    }
}
