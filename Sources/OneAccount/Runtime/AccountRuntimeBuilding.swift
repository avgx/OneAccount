import Foundation

/// Builds a fully wired `AccountRuntime` from a persisted `AccountRecord`.
///
/// Implement this protocol to swap in different HTTP/auth configurations
/// (e.g. test doubles, custom trust policies, debug loggers).
public protocol AccountRuntimeBuilding: Sendable {

    /// Returns `nil` when the account's backend does not require an HTTP client
    /// (e.g. `backend == .none`).
    ///
    /// - Parameters:
    ///   - account: Persisted account record.
    ///   - onAuthRefreshFailed: Called on the cooperative pool when a token refresh
    ///     fails (e.g. 401 with expired refresh token). Caller should surface
    ///     re-login UI, keyed by `AccountID`.
    func build(
        account: AccountRecord,
        onAuthRefreshFailed: @escaping @Sendable (AccountID) -> Void
    ) async -> AccountRuntime?
}
