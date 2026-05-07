import Foundation

public protocol SessionRefresher: Sendable {
    func refresh(_ current: BackendSession?) async throws -> BackendSession
}
