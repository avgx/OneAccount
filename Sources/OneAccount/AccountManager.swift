import Combine
import Foundation

/// UI-facing observable wrapper around ``AccountStore``. Inject via `.environmentObject` in SwiftUI.
@MainActor
public final class AccountManager: ObservableObject {
    
    public let store: AccountStore
    
    @Published public private(set) var accounts: [AccountRecord] = []
    
    public init(store: AccountStore) {
        self.store = store
    }
    
    public func refresh() async throws {
        accounts = try await store.getAll()
    }
}
