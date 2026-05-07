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
        guard let http = error as? HTTPError else { return false }
        //TODO: надо проверить вероятно ещё и 403 а не только 401. посмотреть по реальному подключению
        //TODO: может быть перезапросить при 500+?
        guard http.statusCodeIfUnacceptable == 401 else { return false }
        do {
            _ = try await auth.refresh()
            return true
        } catch {
            return false
        }
    }
}


