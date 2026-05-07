import Foundation

struct OtpVerify: Encodable, Sendable {
    let clientId: String
    let email: String
    let otp: String
    
    init(email: String, otp: String, clientId: String) {
        self.clientId = clientId
        self.email = email
        self.otp = otp
    }
}
