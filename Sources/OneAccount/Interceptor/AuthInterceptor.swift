import Foundation
import HTTP

public final class AuthInterceptor: RequestInterceptor, @unchecked Sendable {
    private let auth: Auth

    /// Bearer access token from ``Auth`` with refresh on 401.
    public init(auth: Auth) {
        self.auth = auth
    }

    public func adapt(_ request: URLRequest) async throws -> URLRequest {
        var request = request
        let token = try await auth.validAccessToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    public func retry(_ request: URLRequest, dueTo error: Error) async -> Bool {
        guard let http = error as? HTTPError, let statusCode = http.statusCodeIfUnacceptable else { return false }
        guard shouldRefresh(for: statusCode) else { return false }
        do {
            _ = try await auth.refresh()
            return true
        } catch {
            return false
        }
    }
    
    /// Refresh token only when auth is likely expired/revoked.
    /// 5xx are server-side and usually not fixed by token refresh.
    private func shouldRefresh(for statusCode: Int) -> Bool {
        return statusCode == 401 //|| statusCode == 403
    }
}


