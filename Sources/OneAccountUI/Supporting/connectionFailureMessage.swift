import Foundation
import HTTP

enum ErrorHelper {
    static func connectionFailureMessage(for error: Error) -> String {
        UserFacingErrorMessage.text(for: error)
    }
}
