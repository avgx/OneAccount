import Foundation

public struct OTPVerificationRequest: Equatable, Sendable {
    public var endpoint: ResolvedEndpoint
    public var user: String
    public var code: String
    public var mode: OtpMode

    public init(endpoint: ResolvedEndpoint, user: String, code: String, mode: OtpMode) {
        self.endpoint = endpoint
        self.user = user
        self.code = code
        self.mode = mode
    }
}
