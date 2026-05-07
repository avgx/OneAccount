import Foundation
import Combine
import HTTP
import DebugThings
import SSLPinning

//TODO: при смене настроек надо пересоздавать `HTTPClient`

@MainActor
public final class CurrentAccount: ObservableObject {
    let manager: AccountManager
    
    let pathStatistics: PathStatistics = PathStatistics()
    private let accountChangedHub = Hub<Changed>()
    
    private var auth: Auth?
    
    public var serverTrustPolicy: ServerTrustPolicy = .system
    public var logger: (any URLSessionTaskLogger)? = nil
    
    @Published public private(set) var account: AccountRecord?
    @Published public private(set) var http: HTTPClient?
    @Published public private(set) var selectedId: AccountID?
    
    public func accountChanged() async -> AsyncStream<Changed> {
        await accountChangedHub.subscribe()
    }
    
    init(manager: AccountManager) {
        self.manager = manager
    }
    
    public func statistics() async -> [String: PathRequestStatistics] {
        await pathStatistics.snapshot()
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
        await auth?.reset()
        await pathStatistics.reset()
        
        var nextAccount: AccountRecord?
        var nextHTTP: HTTPClient?
        
        // Load and apply new session/client if account exists
        if let id = id, let account = try? await manager.get(id) {
            let selectedAuth = makeAuth(for: account) ?? Auth()
            self.auth = selectedAuth
            
            if let session = account.session {
                await selectedAuth.setSession(session)
            }
            
            nextAccount = account
            let client = makeHTTPClient(for: account, auth: selectedAuth)
            nextHTTP = client
            selectedId = id
        } else {
            selectedId = nil
        }
        
        self.account = nextAccount
        self.http = nextHTTP
        
        // Notify didChange
        await accountChangedHub.publish(Changed(
            phase: .didChange,
            oldId: oldId,
            newId: selectedId
        ))
    }
    
    public func current() async -> AccountRecord? {
        guard let id = selectedId else { return nil }
        return try? await manager.get(id)
    }
    
    public func currentId() -> AccountID? {
        selectedId
    }
}
