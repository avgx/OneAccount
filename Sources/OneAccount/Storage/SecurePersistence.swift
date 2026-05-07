import Foundation
import Security

/// Stores each `AccountRecord` as a JSON blob in the Keychain.
/// Items are scoped by `kSecAttrService` (see `service`) and `kSecAttrAccount` = `"\(keyPrefix).\(uuid)"`,
final class SecurePersistence: AccountPersistence, @unchecked Sendable {
    private let keyPrefix: String
    private let service: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// - Parameters:
    ///   - service: `kSecAttrService` — isolates OneAccount entries from other Keychain items.
    init(
        keyPrefix: String = "OneAccount",
        service: String? = nil,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.keyPrefix = keyPrefix
        self.service = service ?? keyPrefix
        self.encoder = encoder
        self.decoder = decoder
    }

    private func accountKey(for id: AccountID) -> String {
        "\(keyPrefix).\(id.uuidString)"
    }

    private let accessibility: CFString = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

    public func save(account: AccountRecord) throws {
        let accountKey = accountKey(for: account.id)
        let data = try encoder.encode(account)
        try deleteItem(accountKey: accountKey)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessibility,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw PersistenceError.writeFailed(NSError(domain: NSOSStatusErrorDomain, code: Int(status)))
        }
    }

    public func load(accountID: AccountID) throws -> AccountRecord? {
        try loadPayload(accountKey: accountKey(for: accountID))
    }

    public func delete(accountID: AccountID) throws {
        try deleteItem(accountKey: accountKey(for: accountID))
    }

    public func exists(accountID: AccountID) throws -> Bool {
        try load(accountID: accountID) != nil
    }

    public func loadAll() throws -> [AccountRecord] {
        var out: [AccountRecord] = []
        for key in try matchingAccountKeys() {
            if let record = try loadPayload(accountKey: key) {
                out.append(record)
            }
        }
        return out
    }

    public func deleteAll() throws {
        for key in try matchingAccountKeys() {
            try deleteItem(accountKey: key)
        }
    }

    public func getAllIDs() throws -> [AccountID] {
        let prefix = "\(keyPrefix)."
        return try matchingAccountKeys().compactMap { accountKey in
            guard accountKey.hasPrefix(prefix) else { return nil }
            let suffix = String(accountKey.dropFirst(prefix.count))
            return UUID(uuidString: suffix)
        }
    }

    // MARK: - Keychain

    private func matchingAccountKeys() throws -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return []
        }
        guard status == errSecSuccess else {
            throw PersistenceError.readFailed(NSError(domain: NSOSStatusErrorDomain, code: Int(status)))
        }
        let prefix = "\(keyPrefix)."
        let items: [[String: Any]]
        if let arr = result as? [[String: Any]] {
            items = arr
        } else if let one = result as? [String: Any] {
            items = [one]
        } else {
            return []
        }
        return items.compactMap { item in
            guard let account = item[kSecAttrAccount as String] as? String,
                  account.hasPrefix(prefix) else { return nil }
            let rest = String(account.dropFirst(prefix.count))
            guard UUID(uuidString: rest) != nil else { return nil }
            return account
        }
    }

    private func loadPayload(accountKey: String) throws -> AccountRecord? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountKey,
            kSecReturnData as String: true,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = result as? Data else {
            throw PersistenceError.readFailed(NSError(domain: NSOSStatusErrorDomain, code: Int(status)))
        }
        do {
            return try decoder.decode(AccountRecord.self, from: data)
        } catch {
            throw PersistenceError.decodingFailed(error)
        }
    }

    private func deleteItem(accountKey: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountKey,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw PersistenceError.writeFailed(NSError(domain: NSOSStatusErrorDomain, code: Int(status)))
        }
    }
}
