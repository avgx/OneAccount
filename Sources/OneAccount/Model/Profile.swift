import Foundation

public struct Profile: Codable, Sendable, Equatable {
    public var name: String?

    public init(name: String? = nil) {
        self.name = name
    }
}
