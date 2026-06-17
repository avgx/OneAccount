import Foundation

/// Free URL entry vs fixed server (URL/backend cannot be changed in the wizard).
public enum EndpointWizardMode: Equatable, Sendable {
    case free
    case locked(ResolvedEndpoint)
}
