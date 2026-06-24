import Foundation
import HTTP

enum ErrorHelper {
    static func connectionFailureMessage(for error: Error) -> String {
        if let httpError = error as? HTTPError {
            return httpError.compactFailureMessage
        }
        if let urlError = error as? URLError, urlError.code == .userAuthenticationRequired {
            return HTTPURLResponse.localizedString(forStatusCode: 401)
        }
        return error.localizedDescription
    }
}
