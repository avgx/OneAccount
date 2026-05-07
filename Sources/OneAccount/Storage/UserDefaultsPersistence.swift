import Foundation

/// Stores each `AccountRecord` as JSON under key `"\(keyPrefix).\(uuid)"` in ``UserDefaults/standard``.
///
/// **Security:** UserDefaults is not encrypted; passwords and tokens are stored in plaintext on disk. Prefer ``SecureAccountPersistence`` for sensitive data.
///
/// Account discovery uses ``UserDefaults/dictionaryRepresentation()`` filtered by `keyPrefix` and a UUID suffix.
final class UserDefaultsPersistence: AccountPersistence, @unchecked Sendable {
    private let userDefaults = UserDefaults.standard
    private let keyPrefix: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        keyPrefix: String = "OneAccount",
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.keyPrefix = keyPrefix
        self.encoder = encoder
        self.decoder = decoder
        encoder.outputFormatting = [.sortedKeys]
    }

    private func keyForAccount(id: AccountID) -> String {
        "\(keyPrefix).\(id.uuidString)"
    }

    private func accountKeys() -> [String] {
        let prefix = "\(keyPrefix)."
        return userDefaults.dictionaryRepresentation().keys.filter { key in
            guard key.hasPrefix(prefix) else { return false }
            let suffix = String(key.dropFirst(prefix.count))
            return UUID(uuidString: suffix) != nil
        }
    }

    public func save(account: AccountRecord) throws {
        let key = keyForAccount(id: account.id)
        do {
            let data = try encoder.encode(account)
            userDefaults.set(data, forKey: key)
        } catch {
            throw PersistenceError.encodingFailed(error)
        }
    }

    public func load(accountID: AccountID) throws -> AccountRecord? {
        let key = keyForAccount(id: accountID)
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }
        do {
            return try decoder.decode(AccountRecord.self, from: data)
        } catch {
            throw PersistenceError.decodingFailed(error)
        }
    }

    public func delete(accountID: AccountID) throws {
        let key = keyForAccount(id: accountID)
        userDefaults.removeObject(forKey: key)
    }

    public func exists(accountID: AccountID) throws -> Bool {
        try load(accountID: accountID) != nil
    }

    public func loadAll() throws -> [AccountRecord] {
        var accounts: [AccountRecord] = []
        for key in accountKeys() {
            guard let data = userDefaults.data(forKey: key) else { continue }
            do {
                accounts.append(try decoder.decode(AccountRecord.self, from: data))
            } catch {
                throw PersistenceError.decodingFailed(error)
            }
        }
        return accounts
    }

    public func deleteAll() throws {
        for key in accountKeys() {
            userDefaults.removeObject(forKey: key)
        }
    }

    public func getAllIDs() throws -> [AccountID] {
        accountKeys().compactMap { key in
            let prefix = "\(keyPrefix)."
            let suffix = String(key.dropFirst(prefix.count))
            return UUID(uuidString: suffix)
        }
    }
}
