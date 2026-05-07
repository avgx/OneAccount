import Foundation

/// Chooses how ``AccountStore`` persists ``AccountRecord`` data. Mostly for tests
public enum AccountStorage: Sendable {
    /// In-process only; nothing is written to disk.
    case memory
    /// JSON in ``UserDefaults/standard``; see ``UserDefaultsPersistence``.
    case userDefaults(keyPrefix: String)
    /// JSON blobs in the Keychain; see ``SecurePersistence``.
    case keychain(keyPrefix: String, service: String)
}

extension AccountStorage {

    public func makePersistence() -> AccountPersistence? {
        switch self {
        case .memory:
            return nil
        case .userDefaults(let keyPrefix):
            return UserDefaultsPersistence(keyPrefix: keyPrefix)
        case .keychain(let keyPrefix, let service):
            return SecurePersistence(keyPrefix: keyPrefix, service: service)
        }
    }

    public func makeStore() -> AccountStore {
        AccountStore(persistence: makePersistence())
    }
}
