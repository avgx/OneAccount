import Foundation
import RequestResponse

enum NextApi {
    /// insecure request
    static func authenticate(user: String, password: String) -> Request<GrpcAuthResponse> {
        let q = [
            ("user_name", user),
        ]
        let body = GrpcAuthRequest(user_name: user, password: password)
        return Request(path: "v1/authentication/authenticate_ex2", method: .post, query: q, body: body)
    }
    /// require valid Bearer auth token
    static func renew() -> Request<GrpcAuthResponse> {
        let q = [
            ("_", "\(Int(Date().timeIntervalSince1970 * 1000))"),
        ]
        return Request(path: "v1/authentication/renew2", method: .get, query: q)
    }
    /// require valid Bearer auth token
    static func close() -> Request<Void> {
        Request(path: "v1/authentication/close", method: .get)
    }
    /// require valid Bearer or Basic auth
    static func test() -> Request<Void> {
        Request(path: "product/version", method: .get)
    }
}
