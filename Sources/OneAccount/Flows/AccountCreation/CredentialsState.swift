import Foundation

public struct CredentialsState: Equatable, Sendable {
    public var failure: FlowFailure?
    public var signInOutcomeKnown = false
    public var needsOtp = false
    public var otpCanTotp = true

    public init(
        failure: FlowFailure? = nil,
        signInOutcomeKnown: Bool = false,
        needsOtp: Bool = false,
        otpCanTotp: Bool = true
    ) {
        self.failure = failure
        self.signInOutcomeKnown = signInOutcomeKnown
        self.needsOtp = needsOtp
        self.otpCanTotp = otpCanTotp
    }

    public static func == (lhs: CredentialsState, rhs: CredentialsState) -> Bool {
        lhs.signInOutcomeKnown == rhs.signInOutcomeKnown
            && lhs.needsOtp == rhs.needsOtp
            && lhs.otpCanTotp == rhs.otpCanTotp
            && (lhs.failure == nil) == (rhs.failure == nil)
    }
}
