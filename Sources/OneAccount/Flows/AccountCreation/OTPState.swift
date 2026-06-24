import Foundation

public struct OTPState: Equatable, Sendable {
    public var code = ""
    public var isTotp = false
    public var canTotp = true
    public var failure: FlowFailure?

    public init(
        code: String = "",
        isTotp: Bool = false,
        canTotp: Bool = true,
        failure: FlowFailure? = nil
    ) {
        self.code = code
        self.isTotp = isTotp
        self.canTotp = canTotp
        self.failure = failure
    }

    public static func == (lhs: OTPState, rhs: OTPState) -> Bool {
        lhs.code == rhs.code
            && lhs.isTotp == rhs.isTotp
            && lhs.canTotp == rhs.canTotp
            && (lhs.failure == nil) == (rhs.failure == nil)
    }
}
