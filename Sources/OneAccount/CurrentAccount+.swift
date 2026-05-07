import Foundation
import Combine
import HTTP
import DebugThings
import SSLPinning

extension CurrentAccount {
    public struct Changed: Sendable {
        public enum Phase: Sendable { case willChange, didChange }
        public let phase: Phase
        public let oldId: AccountID?
        public let newId: AccountID?
        
        public init(phase: Phase, oldId: AccountID?, newId: AccountID?) {
            self.phase = phase
            self.oldId = oldId
            self.newId = newId
        }
    }
    
    func makeAuth(for account: AccountRecord) -> Auth? {
        switch account.backend {
        case .cloud:
            Auth(
                policy: .init(margin: 60),
                refresher: CloudSessionRefresher(baseURL: account.baseURL),
                onPersist: { [weak self] session in
                    try? await self?.manager.updateSession(accountID: account.id, session: session)
                }
            )
        case .next:
            Auth(
                policy: .init(margin: 60),
                refresher: NextSessionRefresher(baseURL: account.baseURL),
                onPersist: { [weak self] session in
                    try? await self?.manager.updateSession(accountID: account.id, session: session)
                }
            )
        case .nextLegacy:
            nil
        case .intl:
            nil
        case .none:
            nil
        }
    }
    
    func makeHTTPClient(for account: AccountRecord, auth: Auth?) -> HTTPClient? {
        switch account.backend {
        case .cloud, .next:
            guard let auth else { return nil }
            return
                HTTPClient(
                    configuration: .custom,
                    redirectDisposition: .doNotFollow,
                    serverTrustPolicy: serverTrustPolicy,
                    interceptor: AuthInterceptor(auth: auth),
                    observer: pathStatistics,
                    logger: logger ?? SimpleURLSessionTaskLogger(), //TODO: default to NoopURLSessionTaskLogger(),
                )
        case .nextLegacy, .intl:
            precondition(!account.password.isEmpty)
            return
                HTTPClient(
                    configuration: .custom,
                    redirectDisposition: .doNotFollow,
                    serverTrustPolicy: serverTrustPolicy,
                    interceptor: FixedAuthInterceptor(
                        authorization: .basic(.init(user: account.user, password: account.password))
                    ),
                    observer: pathStatistics,
                    logger: logger ?? SimpleURLSessionTaskLogger(), //TODO: default to NoopURLSessionTaskLogger(),
                )
            
        case .none:
            return nil
        }
    }
}
