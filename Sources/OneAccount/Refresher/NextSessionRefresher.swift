import Foundation
import HTTP
import RequestResponse
import JWTDecode

public struct NextSessionRefresher: SessionRefresher {
    private let baseURL: URL
    private let credentials: Credentials?

    public init(baseURL: URL, credentials: Credentials? = nil) {
        self.baseURL = baseURL
        self.credentials = credentials
    }

    public func refresh(_ current: BackendSession?) async throws -> BackendSession {
        print(#function)
        guard case .next(let session)? = current else {
            throw URLError(.userAuthenticationRequired)
        }

        let decoded = try decode(jwt: session.authToken)
        if decoded.expiresAt! > Date() {
            return try await renew(bearerToken: session.authToken)
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
            bearerToken: bearerToken
        )

        let response = try await client.send(NextApi.renew(), with: builder).value

        print(response)
        guard let access = response.token_value else {
            throw URLError(.userAuthenticationRequired)
        }

        return .next(NextSession(authToken: access))
    }

    private func authenticate(user: String, password: String) async throws -> BackendSession {
        let builder = RequestBuilder.json(baseURL: baseURL, encoder: JSONEncoder())
        let client = HTTPClient()

        let response = try await client.send(
            NextApi.authenticate(user: user, password: password),
            with: builder
        ).value

        print(response)
        guard response.error_code == .AUTHENTICATE_CODE_OK,
              let token = response.token_value else {
            throw URLError(.userAuthenticationRequired)
        }

        return .next(NextSession(authToken: token))
    }
}
