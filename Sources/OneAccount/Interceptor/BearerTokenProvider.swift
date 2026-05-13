import Foundation

/// Supplies bearer access tokens for ``AuthInterceptor`` without exposing refresh policy details.
public protocol BearerTokenProvider: Sendable {
    func validToken() async throws -> String
    /// Called when a request failed with an auth-related HTTP status and a retry may help.
    func refreshToken() async throws
}

/// Bridges ``Auth`` to ``BearerTokenProvider`` for use with ``AuthInterceptor``.
public final class AuthBearerTokenProvider: BearerTokenProvider, @unchecked Sendable {
    private let auth: Auth

    public init(auth: Auth) {
        self.auth = auth
    }

    public func validToken() async throws -> String {
        try await auth.validAccessToken()
    }

    public func refreshToken() async throws {
        _ = try await auth.refresh()
    }
}
