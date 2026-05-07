import Foundation

public protocol AccountSource: Sendable {
    func get(by id: AccountID) async throws -> AccountRecord?
}
