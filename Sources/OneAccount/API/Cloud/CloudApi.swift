import Foundation
import RequestResponse

enum CloudApi {
    static func login(_ body: LoginV3) -> Request<AuthV3> {
        Request(path: "api/v3/ac-backend/users/login", method: .post, body: body)
    }

    ///Use `Authorization: Bearer refreshToken`
    static func refreshTokens() -> Request<AuthV3> {
        Request(path: "api/v3/ac-backend/auth/tokens", method: .post)
    }

    static func otpVerify(_ body: OtpVerify) -> Request<AuthV3> {
        Request(path: "api/v3/ac-backend/users/otp/verify", method: .post, body: body)
    }

    static func totpVerify(_ body: TotpVerify) -> Request<AuthV3> {
        Request(path: "api/v3/ac-backend/users/totp", method: .patch, body: body)
    }

    static func logout() -> Request<Void> {
        Request(path: "api/v3/ac-backend/users/logout", method: .post)
    }

    static func test() -> Request<Void> {
        //??? api/v3/ac-backend/users/23544
        Request(path: "api/v3/ac-backend/domains/groups", method: .get)
    }
}
