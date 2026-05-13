import Foundation

/// Persisted authentication shape: bearer session for Cloud/Next, password-only backends, or not yet signed in.
public enum AuthMethod: Codable, Sendable, Equatable {
    case basic
    case bearer(BackendSession)

    private enum CodingKeys: String, CodingKey {
        case kind
        case bearer
    }

    private enum Kind: String, Codable {
        case basic
        case bearer
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .kind)
        switch kind {
        case .basic:
            self = .basic
        case .bearer:
            self = .bearer(try c.decode(BackendSession.self, forKey: .bearer))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .basic:
            try c.encode(Kind.basic, forKey: .kind)
        case .bearer(let session):
            try c.encode(Kind.bearer, forKey: .kind)
            try c.encode(session, forKey: .bearer)
        }
    }
}
