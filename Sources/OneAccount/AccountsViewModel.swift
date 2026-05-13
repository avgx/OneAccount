import Combine
import Foundation

/// Observable list of stored accounts. Inject via `.environmentObject` in SwiftUI.
///
/// Does **not** own selection — `CurrentAccount` is the single source of truth
/// for which account is active.
@MainActor
public final class AccountsViewModel: ObservableObject {

    public let store: AccountStore

    @Published public private(set) var accounts: [AccountRecord] = []

    public init(store: AccountStore) {
        self.store = store
    }

    /// Reload accounts from the store, sorted by user name.
    public func refresh() async throws {
        accounts = try await store.getAll()
            .sorted { ($0.credentials.user) < ($1.credentials.user) }
    }

    /// Delete an account and refresh the list.
    public func delete(_ id: AccountID) async throws {
        try await store.delete(id)
        try await refresh()
    }
}
