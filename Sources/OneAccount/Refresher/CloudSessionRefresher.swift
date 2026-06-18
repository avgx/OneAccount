import Foundation
import HTTP
import RequestResponse
import JWTDecode
import DebugThings
import SSLPinning

public struct CloudSessionRefresher: SessionRefresher {
    private let baseURL: URL
    private let serverTrustPolicy: ServerTrustPolicy
    private let logger: (any URLSessionTaskLogger)?
    
    public init(
        baseURL: URL,
        serverTrustPolicy: ServerTrustPolicy = .system,
        logger: (any URLSessionTaskLogger)? = nil
    ) {
        self.baseURL = baseURL
        self.serverTrustPolicy = serverTrustPolicy
        self.logger = logger
    }

    public func refresh(_ current: BackendSession?) async throws -> BackendSession {
        print(#function)
        guard case .cloud(let session)? = current else {
            throw URLError(.userAuthenticationRequired)
        }

        let decoded = try decode(jwt: session.refreshToken)
        guard decoded.expiresAt! > Date(),
                decoded.issuer == "Cloud",
                decoded.claim(name: "Type").string == "refreshToken" else {
            throw URLError(.userAuthenticationRequired)
        }

        let (client, builder) = BearerRefreshTransport.jsonClientAndBuilder(
            baseURL: baseURL,
            bearerToken: session.refreshToken,
            serverTrustPolicy: serverTrustPolicy,
            logger: logger
        )

        let response = try await client.send(CloudApi.refreshTokens(), with: builder).value

        print(response)
        guard let access = response.accessToken,
              let refresh = response.refreshToken else {
            throw URLError(.userAuthenticationRequired)
        }

        return .cloud(
            CloudSession(
                accessToken: access,
                refreshToken: refresh
            )
        )
    }
}
