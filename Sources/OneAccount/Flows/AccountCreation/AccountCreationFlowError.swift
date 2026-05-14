import Foundation

public enum AccountCreationFlowError: LocalizedError, Equatable {
    case missingResolvedEndpoint
    case emptyCredentials
    case emptyOtp

    public var errorDescription: String? {
        switch self {
        case .missingResolvedEndpoint:
            "Select a server before continuing."
        case .emptyCredentials:
            "Enter username and password."
        case .emptyOtp:
            "Enter the verification code."
        }
    }
}
