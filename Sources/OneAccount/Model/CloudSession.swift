import Foundation
import JWTDecode

public struct CloudSession: Codable, Sendable, Equatable {
    public let accessToken: String
    public let refreshToken: String

    private let accessExp: Date?
    private let refreshExp: Date?
    
    public init(
        accessToken: String,
        refreshToken: String
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.accessExp = (try? decode(jwt: accessToken))?.expiresAt
        self.refreshExp = (try? decode(jwt: refreshToken))?.expiresAt
    }

    public var accessExpiresAt: Date? {
        accessExp
    }
    
    public var refreshExpiresAt: Date? {
        refreshExp
    }
    
    public func shouldRefreshAccess(margin: TimeInterval) -> Bool {
        guard let exp = accessExpiresAt else { return false }
        return exp.timeIntervalSinceNow <= margin
    }
}
