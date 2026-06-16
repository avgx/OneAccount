import Foundation
import Combine
import HTTP
import SSLPinning
import DebugThings

@MainActor
public final class CurrentAccount: ObservableObject {

    // MARK: - Public config

    /// Logger applied to the HTTP client inside each new runtime.
    /// Changing this triggers an async runtime rebuild while preserving the session.
    public var logger: (any URLSessionTaskLogger)? = nil {
        didSet { Task { await rebuildRuntime() } }
    }

    // MARK: - Published state

    /// The live runtime for the currently selected account. `nil` when no account is selected.
    @Published public private(set) var runtime: AccountRuntime?

    /// ID of the currently selected account. Single source of truth for selection.
    @Published public private(set) var selectedId: AccountID?

    /// Non-nil when a 401 refresh failure should prompt re-login.
    /// Clear it by calling `clearReloginPrompt()`.
    @Published public private(set) var reloginPromptAccountID: AccountID?

    // MARK: - Internal

    let store: AccountStore
    private var factory: any AccountRuntimeBuilding

    // MARK: - Init

    public init(store: AccountStore, factory: (any AccountRuntimeBuilding)? = nil) {
        self.store = store
        self.factory = factory ?? DefaultAccountRuntimeFactory(store: store)
    }

    // MARK: - Selection

    /// Select an account by ID. Tears down the current runtime, builds a new one,
    /// Pass `nil` to deselect.
    public func selectAccount(id: AccountID?) async {
        reloginPromptAccountID = nil

        await runtime?.shutdown()
        runtime = nil
        selectedId = nil

        if let id, let account = try? await store.get(by: id) {
            let built = await currentFactory().build(account: account) { [weak self] accountID in
                Task { @MainActor in
                    self?.handleRefreshFailed(for: accountID)
                }
            }
            runtime = built
            selectedId = built != nil ? id : nil
        }
    }

    // MARK: - Relogin

    public func clearReloginPrompt() {
        reloginPromptAccountID = nil
    }

    // MARK: - Statistics passthrough

    public func statistics() async -> [String: PathRequestStatistics] {
        guard let rt = runtime else { return [:] }
        return await rt.statistics.snapshot()
    }

    // MARK: - Private

    private func handleRefreshFailed(for accountID: AccountID) {
        if selectedId == accountID {
            reloginPromptAccountID = accountID
        }
    }

    /// Rebuild the runtime for the currently selected account, preserving the selection.
    /// Called when `serverTrustPolicy` or `logger` changes.
    private func rebuildRuntime() async {
        guard let id = selectedId, let account = try? await store.get(by: id) else { return }
        let built = await currentFactory().build(account: account) { [weak self] accountID in
            Task { @MainActor in
                self?.handleRefreshFailed(for: accountID)
            }
        }
        await runtime?.shutdown()
        runtime = built
    }

    private func currentFactory() -> any AccountRuntimeBuilding {
        guard var df = factory as? DefaultAccountRuntimeFactory else {
            return factory
        }
        df.logger = logger
        return df
    }
}
