import Foundation

public actor AccountStore {
    private var cache: [AccountID: AccountRecord] = [:]
    private let persistence: AccountPersistence?
    private var isLoaded = false

    public init(persistence: AccountPersistence? = nil) {
        self.persistence = persistence
    }

    // MARK: - Loading

    public func load() async throws {
        guard !isLoaded else { return }

        if let persistence {
            let accounts = try await persistence.loadAll()
            for account in accounts {
                cache[account.id] = account
            }
        }
        isLoaded = true
    }

    public func loadIfNeeded() async throws {
        if !isLoaded {
            try await load()
        }
    }

    // MARK: - Single Account CRUD

    public func save(_ account: AccountRecord) async throws {
        try await loadIfNeeded()
        try await persistence?.save(account: account)
        cache[account.id] = account
    }

    public func get(by id: AccountID) async throws -> AccountRecord? {
        try await loadIfNeeded()

        if let cached = cache[id] {
            return cached
        }

        if let account = try await persistence?.load(accountID: id) {
            cache[id] = account
            return account
        }

        return nil
    }

    public func delete(_ id: AccountID) async throws {
        try await loadIfNeeded()
        try await persistence?.delete(accountID: id)
        cache.removeValue(forKey: id)
    }

    public func exists(_ id: AccountID) async throws -> Bool {
        try await loadIfNeeded()

        if cache[id] != nil {
            return true
        }

        return try await persistence?.exists(accountID: id) ?? false
    }

    // MARK: - Batch Operations

    public func getAll() async throws -> [AccountRecord] {
        try await loadIfNeeded()
        return Array(cache.values)
    }

    public func getAllIDs() async throws -> [AccountID] {
        try await loadIfNeeded()

        if let persistence {
            return try await persistence.getAllIDs()
        }

        return Array(cache.keys)
    }

    public func deleteAll() async throws {
        try await loadIfNeeded()
        try await persistence?.deleteAll()
        cache.removeAll()
    }

    // MARK: - Update Operations

    public func updateSession(accountID: AccountID, session: BackendSession?) async throws {
        guard var account = try await get(by: accountID) else {
            throw PersistenceError.accountNotFound(accountID)
        }

        if let session {
            account.auth = .bearer(session)
        } else {
            switch account.endpoint.backend {
            case .intl, .nextLegacy:
                account.auth = .basic
            default:
                account.auth = nil
            }
        }
        try await save(account)
    }

    public func updatePassword(accountID: AccountID, password: String) async throws {
        guard var account = try await get(by: accountID) else {
            throw PersistenceError.accountNotFound(accountID)
        }

        account.credentials.password = password
        try await save(account)
    }

    // MARK: - Cache Management

    public func refreshCache(accountID: AccountID) async throws {
        if let account = try await persistence?.load(accountID: accountID) {
            cache[accountID] = account
        }
    }

    public func refreshAllCache() async throws {
        if let persistence {
            let accounts = try await persistence.loadAll()
            cache.removeAll()
            for account in accounts {
                cache[account.id] = account
            }
        }
    }

    public func clearCache() {
        cache.removeAll()
        isLoaded = false
    }
}

extension AccountStore: AccountSource {}

extension AccountStore: SessionPersisting {}
