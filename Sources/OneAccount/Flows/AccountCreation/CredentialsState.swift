import Foundation

public struct CredentialsState: Equatable, Sendable {
    public var message: String?
    public var signInOutcomeKnown = false
    public var needsOtp = false
    public var otpCanTotp = true

    public init(
        message: String? = nil,
        signInOutcomeKnown: Bool = false,
        needsOtp: Bool = false,
        otpCanTotp: Bool = true
    ) {
        self.message = message
        self.signInOutcomeKnown = signInOutcomeKnown
        self.needsOtp = needsOtp
        self.otpCanTotp = otpCanTotp
    }
}
