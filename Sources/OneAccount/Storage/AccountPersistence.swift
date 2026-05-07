import Foundation

public protocol AccountPersistence: Sendable {
    // Single account operations
    func save(account: AccountRecord) throws
    func load(accountID: AccountID) throws -> AccountRecord?
    func delete(accountID: AccountID) throws
    func exists(accountID: AccountID) throws -> Bool
    
    // Batch operations
    func loadAll() throws -> [AccountRecord]
    func deleteAll() throws
    
    // Utility
    func getAllIDs() throws -> [AccountID]
}

public enum PersistenceError: Error, Sendable {
    case encodingFailed(Error)
    case decodingFailed(Error)
    case writeFailed(Error)
    case readFailed(Error)
    case accountNotFound(AccountID)
}
