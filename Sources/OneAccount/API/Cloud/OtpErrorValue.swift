import Foundation

//TODO: нужно вписать в ответ `AuthV3`
//{"needOTPCheck":true,"totpEnabledProviders":["microsoft"]}
//OTP code from Microsoft Authenticator app
//{"enabledOTP":true,"needOTPCheck":true,"totpEnabledProviders":["microsoft"]}
//both
//{"enabledOTP":true,"needOTPCheck":true}
//email otp

struct OtpErrorValue : Codable, Sendable {
    let otpLoginAttemptsLeft: String
    let otpLoginRetryAfterSec: String
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
