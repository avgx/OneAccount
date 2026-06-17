import Foundation

public struct EndpointStepState: Equatable, Sendable {
    public var urlText: String = ""
    public var isResolving = false
    public var message: String?

    public init(urlText: String = "", isResolving: Bool = false, message: String? = nil) {
        self.urlText = urlText
        self.isResolving = isResolving
        self.message = message
    }
}
