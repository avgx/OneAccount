import Foundation

public enum AccountSignInOutcome: Equatable, Sendable {
    case authenticated(session: BackendSession?)
    case needsOtp(canTotp: Bool)
}
