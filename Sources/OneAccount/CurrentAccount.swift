import Foundation

//TODO: CurrentAccount это для использования в SwiftUI

//TODO: может добавить
//public var http: HTTPClient
//TODO: может сделать так:
//@MainActor public final class CurrentAccount: ObservableObject
//@Published public private(set) var account: AccountRecord = .invalid
//public func setAccount(id: AccountID?)
//TODO: может использовать AccountStorage а AccountStore вообще сделать внутренним?

@MainActor
public final class CurrentAccount: ObservableObject {
    public struct Changed: Sendable {
        public enum Phase: Sendable { case willChange, didChange }
        public let phase: Phase
        public let oldId: UUID?
        public let newId: UUID?
        
        public init(phase: Phase, oldId: UUID?, newId: UUID?) {
            self.phase = phase
            self.oldId = oldId
            self.newId = newId
        }
    }
    
    private let store: AccountStore
    private var auth: Auth
    private var selectedId: AccountID?
    
    private let accountChangedHub = Hub<Changed>()
    
    public func accountChanged() async -> AsyncStream<Changed> {
        await accountChangedHub.subscribe()
    }
    
    public init(storage: AccountStorage) {
        self.store = storage.makeStore()
        self.auth = Auth()  //TODO: .invalid ?
    }
    
    private func makeAuth(for account: AccountRecord) -> Auth? {
        switch account.backend {
        case .cloud:
            Auth(
                policy: .init(margin: 60),
                refresher: CloudSessionRefresher(baseURL: account.baseURL),
                onPersist: { [weak self] session in
                    try? await self?.store.updateSession(accountID: account.id, session: session)
                }
            )
        case .next:
            Auth(
                policy: .init(margin: 60),
                refresher: NextSessionRefresher(baseURL: account.baseURL),
                onPersist: { [weak self] session in
                    try? await self?.store.updateSession(accountID: account.id, session: session)
                }
            )
        case .nextLegacy:
            nil
        case .intl:
            nil
        }
    }
    
    public func selectAccount(id: AccountID?) async {
        let oldId = selectedId
        
        // Notify willChange
        await accountChangedHub.publish(Changed(
            phase: .willChange,
            oldId: oldId,
            newId: id
        ))
        
        // Reset auth state
        await auth.reset()
        
        // Load and apply new session if exists
        if let id = id, let account = try? await store.get(id) {
            if let auth = makeAuth(for: account) {
                self.auth = auth
                if let session = account.session {
                    await auth.setSession(session)
                }
            }
            selectedId = id
        } else {
            selectedId = nil
        }
        
        // Notify didChange
        await accountChangedHub.publish(Changed(
            phase: .didChange,
            oldId: oldId,
            newId: selectedId
        ))
    }
    
    public func current() async -> AccountRecord? {
        guard let id = selectedId else { return nil }
        return try? await store.get(id)
    }
    
    public func currentId() -> AccountID? {
        selectedId
    }
}
