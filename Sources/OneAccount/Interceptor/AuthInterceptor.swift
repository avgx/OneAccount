import Foundation
import HTTP

public final class AuthInterceptor: RequestInterceptor, @unchecked Sendable {
    private let bearerTokenProvider: any BearerTokenProvider
    private let onRefreshFailed: (@Sendable () -> Void)?

    public init(
        bearerTokenProvider: any BearerTokenProvider,
        onRefreshFailed: (@Sendable () -> Void)? = nil
    ) {
        self.bearerTokenProvider = bearerTokenProvider
        self.onRefreshFailed = onRefreshFailed
    }

    /// Bearer access token from ``Auth`` with refresh on 401.
    public convenience init(auth: Auth, onRefreshFailed: (@Sendable () -> Void)? = nil) {
        self.init(bearerTokenProvider: AuthBearerTokenProvider(auth: auth), onRefreshFailed: onRefreshFailed)
    }

    public func adapt(_ request: URLRequest) async throws -> URLRequest {
        var request = request
        let token = try await bearerTokenProvider.validToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    public func retry(_ request: URLRequest, dueTo error: Error) async -> Bool {
        guard let http = error as? HTTPError, let statusCode = http.statusCodeIfUnacceptable else { return false }
        guard shouldRefresh(for: statusCode) else { return false }
        do {
            try await bearerTokenProvider.refreshToken()
            return true
        } catch {
            onRefreshFailed?()
            return false
        }
    }

    /// Refresh token only when auth is likely expired/revoked.
    /// 5xx are server-side and usually not fixed by token refresh.
    private func shouldRefresh(for statusCode: Int) -> Bool {
        statusCode == 401 //|| statusCode == 403
    }
}
