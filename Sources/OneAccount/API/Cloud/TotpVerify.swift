import Foundation

struct TotpVerify: Encodable, Sendable {
    let provider = "microsoft"
    let clientId: String
    let email: String
    let totp: String
    
    init(email: String, totp: String, clientId: String) {
        self.clientId = clientId
        self.email = email
        self.totp = totp
    }
}
