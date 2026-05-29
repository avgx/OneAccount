import Foundation

public actor Auth {
    
    private var storage: BackendSession?
    private var refreshTask: Task<BackendSession, Error>?
    private let policy: RefreshPolicy
    private let refresher: (any SessionRefresher)?
    private let onPersist: (@Sendable (BackendSession) async -> Void)?
    
    public init(
        policy: RefreshPolicy = .init(margin: 60),
        refresher: (any SessionRefresher)? = nil,
        onPersist: (@Sendable (BackendSession) async -> Void)? = nil
    ) {
        self.policy = policy
        self.refresher = refresher
        self.onPersist = onPersist
    }
    
    // MARK: - Public API
    
    public func setSession(_ session: BackendSession) {
        storage = session
    }
        
    public func validAccessToken(refreshIfNeeded: Bool = true) async throws -> String {
        if let token = storage?.accessToken {
            let needsRefresh = refreshIfNeeded && (shouldProactivelyRefresh() || isAccessTokenExpired())
            if needsRefresh {
                return try await refresh()
            }
            return token
        }
        guard refreshIfNeeded else {
            throw URLError(.userAuthenticationRequired)
        }
        return try await refresh()
    }
    
    public func refresh() async throws -> String {
        guard refresher != nil else {
            throw URLError(.userAuthenticationRequired)
        }
        let output = try await performRefresh()
        return output.accessToken
    }
    
    public func reset() {
        refreshTask?.cancel()
        refreshTask = nil
        storage = nil
    }
    
    // MARK: - Private
    
    private func shouldProactivelyRefresh() -> Bool {
        guard let margin = policy.refreshMargin, margin > 0,
              let storage = storage else { return false }
        return storage.shouldRefresh(margin: margin)
    }

    private func isAccessTokenExpired() -> Bool {
        guard let exp = storage?.accessExpiresAt else { return true }
        return exp <= Date()
    }
    
    private func performRefresh() async throws -> BackendSession {
        if let task = refreshTask {
            return try await task.value
        }
        
        let task = Task<BackendSession, Error> {
            defer { refreshTask = nil }
            
            guard let refresher else {
                throw URLError(.userAuthenticationRequired)
            }
            
            let newSession = try await refresher.refresh(storage)
            
            // Update storage based on refresh result
            storage = newSession
            
            // Persist updated session
            await onPersist?(newSession)
            
            return newSession
        }
        
        refreshTask = task
        return try await task.value
    }
}
