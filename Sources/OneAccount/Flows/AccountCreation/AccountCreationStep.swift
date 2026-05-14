import Foundation

public enum AccountCreationStep: Hashable, Sendable {
    case endpoint
    case serverCertificates
    case credentials
    case otp
    case done
}


