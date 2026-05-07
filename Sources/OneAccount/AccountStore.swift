import Foundation

public actor AccountStore {
    private var cache: [AccountID: AccountRecord] = [:]
    private let persistence: AccountPersistence?
    private var isLoaded = false
    
    public init(persistence: AccountPersistence? = nil) {
        self.persistence = persistence
    }
    
    // MARK: - Loading
    
    public func load() throws {
        guard !isLoaded else { return }
        
        if let persistence = persistence {
            let accounts = try persistence.loadAll()
            for account in accounts {
                cache[account.id] = account
            }
        }
        isLoaded = true
    }
    
    public func loadIfNeeded() throws {
        if !isLoaded {
            try load()
        }
    }
    
    // MARK: - Single Account CRUD
    
    public func save(_ account: AccountRecord) throws {
        try loadIfNeeded()
        
        cache[account.id] = account
        
        if let persistence = persistence {
            try persistence.save(account: account)
        }
    }
    
    /// Loads one account from cache or persistence (synchronous within the actor).
    private func record(for id: AccountID) throws -> AccountRecord? {
        try loadIfNeeded()
        
        if let cached = cache[id] {
            return cached
        }
        
        if let persistence = persistence {
            let account = try persistence.load(accountID: id)
            cache[id] = account
            return account
        }
        
        return nil
    }
    
    public func get(by id: AccountID) throws -> AccountRecord? {
        try record(for: id)
    }
    
    public func delete(_ id: AccountID) throws {
        try loadIfNeeded()
        
        cache.removeValue(forKey: id)
        
        if let persistence = persistence {
            try persistence.delete(accountID: id)
        }
    }
    
    public func exists(_ id: AccountID) throws -> Bool {
        try loadIfNeeded()
        
        if cache[id] != nil {
            return true
        }
        
        if let persistence = persistence {
            return try persistence.exists(accountID: id)
        }
        
        return false
    }
    
    // MARK: - Batch Operations
    
    public func getAll() throws -> [AccountRecord] {
        try loadIfNeeded()
        return Array(cache.values)
    }
    
    public func getAllIDs() throws -> [AccountID] {
        try loadIfNeeded()
        
        if let persistence = persistence {
            return try persistence.getAllIDs()
        }
        
        return Array(cache.keys)
    }
    
    public func deleteAll() throws {
        try loadIfNeeded()
        
        cache.removeAll()
        
        if let persistence = persistence {
            try persistence.deleteAll()
        }
    }
    
    // MARK: - Update Operations
    
    private func applySessionUpdate(accountID: AccountID, session: BackendSession?) throws {
        guard var account = try record(for: accountID) else {
            throw PersistenceError.accountNotFound(accountID)
        }
        
        account.session = session
        try save(account)
    }
    
    public func updateSession(accountID: AccountID, session: BackendSession?) throws {
        try applySessionUpdate(accountID: accountID, session: session)
    }
    
    public func updatePassword(accountID: AccountID, password: String) throws {
        guard var account = try record(for: accountID) else {
            throw PersistenceError.accountNotFound(accountID)
        }
        
        account.password = password
        try save(account)
    }
    
    // MARK: - Cache Management
    
    public func refreshCache(accountID: AccountID) throws {
        if let persistence = persistence {
            let account = try persistence.load(accountID: accountID)
            cache[accountID] = account
        }
    }
    
    public func refreshAllCache() throws {
        if let persistence = persistence {
            let accounts = try persistence.loadAll()
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

extension AccountStore: AccountSource {
    public func get(by id: AccountID) async throws -> AccountRecord? {
        try record(for: id)
    }
}

extension AccountStore: SessionPersisting {
    public func updateSession(accountID: AccountID, session: BackendSession?) async throws {
        try applySessionUpdate(accountID: accountID, session: session)
    }
}
