import Foundation
import HTTP

/// Basic credentials with no session to refresh.
/// A 401 means the stored password was rejected. 5xx still retries, same as ``FixedAuthInterceptor``.
public final class BasicAuthInterceptor: RequestInterceptor, Sendable {
    public let authorization: Authorization
    private let onAuthRejected: (@Sendable () -> Void)?

    public init(
        authorization: Authorization,
        onAuthRejected: (@Sendable () -> Void)? = nil
    ) {
        self.authorization = authorization
        self.onAuthRejected = onAuthRejected
    }

    public convenience init(
        user: String,
        password: String,
        onAuthRejected: (@Sendable () -> Void)? = nil
    ) {
        self.init(
            authorization: .basic(.init(user: user, password: password)),
            onAuthRejected: onAuthRejected
        )
    }

    public func adapt(_ request: URLRequest) async throws -> URLRequest {
        var request = request
        if let header = authorization.header, !header.isEmpty {
            request.setValue(header, forHTTPHeaderField: "Authorization")
        }
        return request
    }

    public func retry(_ request: URLRequest, dueTo error: any Error) async -> Bool {
        guard let http = error as? HTTPError, let statusCode = http.statusCodeIfUnacceptable else {
            return false
        }
        if statusCode == 401 {
            onAuthRejected?()
            return false
        }
        return statusCode >= 500
    }
}
