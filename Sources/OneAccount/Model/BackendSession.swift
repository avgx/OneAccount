import Foundation

public enum BackendSession: Codable, Sendable, Equatable {
    case next(NextSession)
    case cloud(CloudSession)

    private enum CodingKeys: String, CodingKey {
        case type
        case next
        case cloud
    }

    private enum Kind: String, Codable {
        case next
        case cloud
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(Kind.self, forKey: .type)

        switch type {
        case .next:
            let session = try container.decode(NextSession.self, forKey: .next)
            self = .next(session)

        case .cloud:
            let session = try container.decode(CloudSession.self, forKey: .cloud)
            self = .cloud(session)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .next(let session):
            try container.encode(Kind.next, forKey: .type)
            try container.encode(session, forKey: .next)

        case .cloud(let session):
            try container.encode(Kind.cloud, forKey: .type)
            try container.encode(session, forKey: .cloud)
        }
    }
}

extension BackendSession {
    public var accessToken: String {
        switch self {
        case .next(let session): return session.authToken
        case .cloud(let session): return session.accessToken
        }
    }
    
    public var accessExpiresAt: Date? {
        switch self {
        case .next(let session): return session.accessExpiresAt
        case .cloud(let session): return session.accessExpiresAt
        }
    }
    
    public func shouldRefresh(margin: TimeInterval) -> Bool {
        switch self {
        case .next(let session): return session.shouldRefresh(margin: margin)
        case .cloud(let session): return session.shouldRefreshAccess(margin: margin)
        }
    }
}
