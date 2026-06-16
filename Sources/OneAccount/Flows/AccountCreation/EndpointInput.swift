import Foundation

public struct EndpointInput: Equatable, Sendable {
    public var rawURL: String

    public init(rawURL: String) {
        self.rawURL = rawURL
    }
}
