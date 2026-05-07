import Foundation

public typealias AccountID = UUID

extension AccountID {
    public static let invalidAccountID: AccountID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
}

public struct AccountRecord: Codable, Identifiable, Sendable, Equatable, CustomStringConvertible {
    public let id: AccountID
    public var name: String?
    public var baseURL: URL
    public var user: String
    public var password: String?
    public var backend: Backend
    public var session: BackendSession?
    
    public init(
        id: UUID = UUID(),
        baseURL: URL,
        backend: Backend,
        user: String,
        password: String? = nil,
        name: String? = nil,
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
        "\(id) \(name ?? user) (\(baseURL.absoluteString))"
    }
}
