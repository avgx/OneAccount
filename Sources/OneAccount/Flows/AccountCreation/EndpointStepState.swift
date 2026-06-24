import Foundation

public struct EndpointStepState: Equatable, Sendable {
    public var urlText: String = ""
    public var failure: FlowFailure?

    public init(urlText: String = "", failure: FlowFailure? = nil) {
        self.urlText = urlText
        self.failure = failure
    }

    public static func == (lhs: EndpointStepState, rhs: EndpointStepState) -> Bool {
        lhs.urlText == rhs.urlText && (lhs.failure == nil) == (rhs.failure == nil)
    }
}
