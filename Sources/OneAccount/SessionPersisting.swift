import Foundation

public protocol SessionPersisting: Sendable {
    func updateSession(accountID: AccountID, session: BackendSession?) async throws
}
