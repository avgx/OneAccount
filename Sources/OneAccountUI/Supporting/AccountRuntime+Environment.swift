import SwiftUI
import OneAccount

private struct AccountRuntimeKey: EnvironmentKey {
    static let defaultValue: AccountRuntime? = nil
}

extension EnvironmentValues {
    /// The active `AccountRuntime` for the current selection.
    /// Set it from the composition root (alongside `currentAccount.runtime`).
    ///
    /// Usage in a deep view:
    /// ```swift
    /// @Environment(\.accountRuntime) private var runtime
    /// let http = await runtime?.http
    /// ```
    public var accountRuntime: AccountRuntime? {
        get { self[AccountRuntimeKey.self] }
        set { self[AccountRuntimeKey.self] = newValue }
    }
}

extension View {
    /// Convenience modifier that keeps `\.accountRuntime` in sync with `CurrentAccount`.
    public func accountRuntime(_ runtime: AccountRuntime?) -> some View {
        environment(\.accountRuntime, runtime)
    }
}
