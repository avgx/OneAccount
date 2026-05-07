import Foundation

public typealias AccountID = UUID

extension AccountID {
    public static let invalidAccountID: AccountID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
}

extension URL {
    public static let invalidURL: URL = URL(string: "invalid://")!
}

extension AccountRecord {
    public static let invalid: AccountRecord = .init(id: .invalidAccountID, baseURL: .invalidURL, user: "", password: "")
}

public struct AccountRecord: Codable, Identifiable, Sendable, Equatable, CustomStringConvertible {
    public let id: AccountID
    public var name: String?
    public var baseURL: URL
    public var user: String
    public var password: String
    public var backend: Backend?
    public var session: BackendSession?
    
    public init(
        id: UUID = UUID(),
        baseURL: URL,
        user: String,
        password: String,
        name: String? = nil,
        backend: Backend? = nil,
        session: BackendSession? = nil
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.backend = backend
        self.user = user
        self.password = password
        self.session = session
    }
    
    public var description: String {
        "\(id) \(name ?? "-") \(backend?.rawValue ?? "?") \(user) (\(baseURL.absoluteString))"
    }
}
