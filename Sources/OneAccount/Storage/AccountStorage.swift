import Foundation

/// Chooses how ``AccountStore`` persists ``AccountRecord`` data. Mostly for tests
public enum AccountStorage: Sendable {
    /// In-process only; nothing is written to disk.
    case memory
    /// JSON blobs in the Keychain; see ``SecurePersistence``.
    /// - Parameter accessGroup: Shared keychain access group so NSE can read accounts.
    ///   Pass `KeychainAccessGroup.fromMainBundle()` when `KEYCHAIN_GROUP_ID` is set in Info.plist;
    ///   `nil` when `KEYCHAIN_GROUP_ID = *` (app default access group).
    case keychain(keyPrefix: String, service: String, accessGroup: String? = nil)
}

extension AccountStorage {

    public func makePersistence() -> AccountPersistence? {
        switch self {
        case .memory:
            return nil
        case .keychain(let keyPrefix, let service, let accessGroup):
            return SecurePersistence(keyPrefix: keyPrefix, service: service, accessGroup: accessGroup)
        }
    }

    public func makeStore() -> AccountStore {
        AccountStore(persistence: makePersistence())
    }
}
