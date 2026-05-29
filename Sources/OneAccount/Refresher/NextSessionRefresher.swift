import Foundation
import HTTP
import RequestResponse
import JWTDecode
import DebugThings

public struct NextSessionRefresher: SessionRefresher {
    private let baseURL: URL
    private let credentials: Credentials?
    private let logger: (any URLSessionTaskLogger)?
    public init(baseURL: URL, credentials: Credentials? = nil, logger: (any URLSessionTaskLogger)? = nil) {
        self.baseURL = baseURL
        self.credentials = credentials
        self.logger = logger
    }

    public func refresh(_ current: BackendSession?) async throws -> BackendSession {
        guard case .next(let session)? = current else {
            throw URLError(.userAuthenticationRequired)
        }

        let decoded = try decode(jwt: session.authToken)
        let expiresAt = decoded.expiresAt
        // renew2 accepts only a still-valid bearer; expired tokens must re-authenticate.
        let canRenew = expiresAt.map { $0 > Date() } ?? false

        if canRenew {
            do {
                return try await renew(bearerToken: session.authToken)
            } catch {
                guard let creds = credentials else { throw error }
                return try await authenticate(user: creds.user, password: creds.password)
            }
        }

        guard let creds = credentials else {
            throw URLError(.userAuthenticationRequired)
        }
        return try await authenticate(user: creds.user, password: creds.password)
    }

    // MARK: - Private

    private func renew(bearerToken: String) async throws -> BackendSession {
        let (client, builder) = BearerRefreshTransport.jsonClientAndBuilder(
            baseURL: baseURL,
            bearerToken: bearerToken,
            logger: logger
        )

        let response = try await client.send(NextApi.renew(), with: builder).value

        guard let access = response.token_value else {
            throw URLError(.userAuthenticationRequired)
        }

        return .next(NextSession(authToken: access))
    }

    private func authenticate(user: String, password: String) async throws -> BackendSession {
        let builder = RequestBuilder.json(baseURL: baseURL, encoder: JSONEncoder())
        let client = HTTPClient(logger: logger ?? NoopURLSessionTaskLogger())

        let response = try await client.send(
            NextApi.authenticate(user: user, password: password),
            with: builder
        ).value

        guard response.error_code == .AUTHENTICATE_CODE_OK,
              let token = response.token_value else {
            throw URLError(.userAuthenticationRequired)
        }

        return .next(NextSession(authToken: token))
    }
}
