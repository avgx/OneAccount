import Foundation

public protocol AccountPersistence: Sendable {
    func save(account: AccountRecord) async throws
    func load(accountID: AccountID) async throws -> AccountRecord?
    func delete(accountID: AccountID) async throws
    func exists(accountID: AccountID) async throws -> Bool

    func loadAll() async throws -> [AccountRecord]
    func deleteAll() async throws

    func getAllIDs() async throws -> [AccountID]
}
