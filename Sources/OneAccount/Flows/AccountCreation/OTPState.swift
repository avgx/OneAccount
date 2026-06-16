import Foundation

public struct OTPState: Equatable, Sendable {
    public var code = ""
    public var isTotp = false
    public var canTotp = true
    public var isVerifying = false
    public var message: String?

    public init(
        code: String = "",
        isTotp: Bool = false,
        canTotp: Bool = true,
        isVerifying: Bool = false,
        message: String? = nil
    ) {
        self.code = code
        self.isTotp = isTotp
        self.canTotp = canTotp
        self.isVerifying = isVerifying
        self.message = message
    }
}
