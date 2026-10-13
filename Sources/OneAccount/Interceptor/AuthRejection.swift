import Foundation
import HTTP

/// Failures that mean the stored credentials cannot continue the session.
enum AuthRejection {
    static func isRejection(_ error: Error) -> Bool {
        if let urlError = error as? URLError, urlError.code == .userAuthenticationRequired {
            return true
        }
        if let http = error as? HTTPError, http.statusCodeIfUnacceptable == 401 {
            return true
        }
        guard let auth = error as? AuthServiceError else { return false }
        switch auth {
        case .nextAuthRejected(let code, _) where Self.rejectedNextCodes.contains(code):
            return true
        default:
            return false
        }
    }

    private static let rejectedNextCodes: Set<EAuthenticateCode?> = [
        .AUTHENTICATE_CODE_WRONG_CREDENTIALS,
        .AUTHENTICATE_CODE_PASSWORD_INVALID,
        .AUTHENTICATE_CODE_USER_LOCKED,
    ]
}
