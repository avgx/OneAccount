import Foundation

public struct Endpoint: Codable, Sendable, Equatable {
    public var url: URL
    public var backend: Backend?

    public init(url: URL, backend: Backend? = nil) {
        self.url = url
        self.backend = backend
    }
}

extension Endpoint: Identifiable {
    public var id: String { url.absoluteString }
}

public struct ResolvedEndpoint: Equatable, Sendable {
    public var url: URL
    public var backend: Backend
    public var name: String?

    public init(url: URL, backend: Backend, name: String? = nil) {
        self.url = url
        self.backend = backend
        self.name = name
    }
}
