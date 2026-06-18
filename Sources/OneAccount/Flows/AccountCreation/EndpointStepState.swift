import Foundation

public struct EndpointStepState: Equatable, Sendable {
    public var urlText: String = ""
    public var message: String?

    public init(urlText: String = "", message: String? = nil) {
        self.urlText = urlText
        self.message = message
    }
}
