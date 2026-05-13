import Foundation

//                        {"description":"wrong password","key":"error.wrong.password"}
// {"code":400,"description":"totp invalid code","key":"error.totp.invalid.code"}

struct ErrorDescription: Codable {
    let key: String?
    let description: String?
    public let message: String?
}
