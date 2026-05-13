import Foundation

public enum AccountCreationStep: Hashable, Sendable {
    case endpoint
    case serverCertificates
    case credentials
    case otp
    case done
}

/// Free URL entry vs fixed server (URL/backend cannot be changed in the wizard).
public enum EndpointWizardMode: Equatable, Sendable {
    case free
    case locked(Endpoint)
}
