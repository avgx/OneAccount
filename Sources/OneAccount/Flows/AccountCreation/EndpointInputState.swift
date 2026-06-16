import Foundation

public struct EndpointInputState: Equatable, Sendable {
    public var isResolving = false
    public var message: String?

    public init(isResolving: Bool = false, message: String? = nil) {
        self.isResolving = isResolving
        self.message = message
    }
}
