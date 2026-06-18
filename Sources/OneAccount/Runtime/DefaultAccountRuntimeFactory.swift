import Foundation
import HTTP
import DebugThings
import SSLPinning

/// Default runtime factory. Assembles `Auth` + `HTTPClient` + `PathStatistics`
/// according to the account's backend. Inject via `CurrentAccount.init`.
public struct DefaultAccountRuntimeFactory: AccountRuntimeBuilding, @unchecked Sendable {

    public var logger: (any URLSessionTaskLogger)?

    private let store: AccountStore

    public init(
        store: AccountStore,
        logger: (any URLSessionTaskLogger)? = nil
    ) {
        self.store = store
        self.logger = logger
    }

    public func build(
        account: AccountRecord,
        onAuthRefreshFailed: @escaping @Sendable (AccountID) -> Void
    ) async -> AccountRuntime? {
        let statistics = PathStatistics()
        let auth = makeAuth(for: account)

        if let auth, case .bearer(let session) = account.auth {
            await auth.setSession(session)
        }

        guard let http = makeHTTPClient(
            for: account,
            auth: auth,
            statistics: statistics,
            onAuthRefreshFailed: onAuthRefreshFailed
        ) else {
            return nil
        }

        return AccountRuntime(account: account, auth: auth, http: http, statistics: statistics)
    }

    // MARK: - Auth

    private func makeAuth(for account: AccountRecord) -> Auth? {
        let accountID = account.id
        switch account.endpoint.backend {
        case .cloud:
            let refresher: any BackendAuthenticator = CloudSessionRefresher(
                baseURL: account.endpoint.url,
                serverTrustPolicy: account.serverTrustPolicy,
                logger: logger
            )
            return Auth(
                policy: .init(margin: 60),
                refresher: refresher,
                onPersist: { [store] session in
                    try? await store.updateSession(accountID: accountID, session: session)
                }
            )
        case .next:
            let refresher: any BackendAuthenticator = NextSessionRefresher(
                baseURL: account.endpoint.url,
                credentials: account.credentials,
                serverTrustPolicy: account.serverTrustPolicy,
                logger: logger
            )
            return Auth(
                policy: .init(margin: 60),
                refresher: refresher,
                onPersist: { [store] session in
                    try? await store.updateSession(accountID: accountID, session: session)
                }
            )
        case .nextLegacy, .intl, .none:
            return nil
        }
    }

    // MARK: - HTTP

    private func makeHTTPClient(
        for account: AccountRecord,
        auth: Auth?,
        statistics: PathStatistics,
        onAuthRefreshFailed: @escaping @Sendable (AccountID) -> Void
    ) -> HTTPClient? {
        let accountID = account.id
        switch account.endpoint.backend {
        case .cloud, .next:
            guard let auth else { return nil }
            let interceptor = AuthInterceptor(auth: auth) {
                onAuthRefreshFailed(accountID)
            }
            return HTTPClient(
                configuration: .custom,
                redirectDisposition: .doNotFollow,
                serverTrustPolicy: account.serverTrustPolicy,
                interceptor: interceptor,
                observer: statistics,
                logger: logger ?? NoopURLSessionTaskLogger()
            )
        case .nextLegacy, .intl:
            precondition(!account.credentials.password.isEmpty)
            return HTTPClient(
                configuration: .custom,
                redirectDisposition: .doNotFollow,
                serverTrustPolicy: account.serverTrustPolicy,
                interceptor: FixedAuthInterceptor(
                    authorization: .basic(
                        .init(user: account.credentials.user, password: account.credentials.password)
                    )
                ),
                observer: statistics,
                logger: logger ?? NoopURLSessionTaskLogger()
            )
        case .none:
            return nil
        }
    }
}
