import Foundation

struct LoginV3: Codable, Sendable {
    let email: String
    let password: String
    let locale: String //locale
    let clientId: String
    
    init(email: String, password: String, locale: String, clientId: String) {
        self.clientId = clientId
        self.email = email
        self.password = password
        self.locale = locale
    }
}
