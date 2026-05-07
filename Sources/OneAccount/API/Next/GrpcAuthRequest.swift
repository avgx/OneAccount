import Foundation

struct GrpcAuthRequest: Codable, Sendable {
    let user_name: String
    let password: String
}
