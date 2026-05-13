import Foundation
import HTTP

/// Isolated runtime container for a single authenticated account.
/// Owns the HTTP client, auth state, and request statistics for the
/// lifetime of a selection. Replace the whole instance on config change.
public actor AccountRuntime {

    public let account: AccountRecord
    public let auth: Auth?
    public let http: HTTPClient
    public let statistics: PathStatistics

    private var isShutdown = false

    public init(
        account: AccountRecord,
        auth: Auth?,
        http: HTTPClient,
        statistics: PathStatistics
    ) {
        self.account = account
        self.auth = auth
        self.http = http
        self.statistics = statistics
    }

    /// Tear down the runtime: cancel in-flight refresh, reset statistics.
    func shutdown() async {
        guard !isShutdown else { return }
        isShutdown = true
        await auth?.reset()
        await statistics.reset()
    }
}
