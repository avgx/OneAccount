import Foundation

public struct OtpErrorValue: Codable, Sendable {
    public let otpLoginAttemptsLeft: String?
    public let otpLoginRetryAfterSec: String?
    
    public var attemptsLeft: Int? {
        guard let otpLoginAttemptsLeft else { return nil }
        return Int(otpLoginAttemptsLeft)
    }
    
    public var retryAfterSeconds: Int? {
        guard let otpLoginRetryAfterSec else { return nil }
        return Int(otpLoginRetryAfterSec)
    }
}

//            {
//              "description": "error.otp.wrong",
//              "key": "error.otp.wrong",
//              "inner": null,
//              "values": {
//                "otpLoginAttemptsLeft": "2",
//                "otpLoginRetryAfterSec": "0"
//              }
//            }
            
//            {
//              "description": "error.otp.too.many.failed.attempts",
//              "key": "error.otp.too.many.failed.attempts",
//              "inner": null,
//              "values": {
//                "otpLoginAttemptsLeft": "0",
//                "otpLoginRetryAfterSec": "600"
//              }
//            }
