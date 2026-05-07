import Foundation
import HTTP
import RequestResponse
import JWTDecode

public struct NextSessionRefresher: SessionRefresher {
    private let baseURL: URL

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }

    public func refresh(_ current: BackendSession?) async throws -> BackendSession {
        print(#function)
        guard case .next(let session)? = current else {
            throw URLError(.userAuthenticationRequired)
        }

        let decoded = try decode(jwt: session.authToken)
        guard decoded.expiresAt! > Date() else {
            throw URLError(.userAuthenticationRequired)
        }
        
        let client = HTTPClient(
            interceptor: FixedAuthInterceptor(authorization: .bearer(session.authToken)),
            //observer: LoggingRequestObserver(logger: Logger(label: "auth")),
            //logger: SimpleURLSessionTaskLogger(label: "auth", logReceiveData: true)
        )
        
        let builder = RequestBuilder.json(baseURL: baseURL, encoder: JSONEncoder())
        
        let response = try await client.send(NextApi.renew(), with: builder).value

        print(response)
        guard let access = response.token_value else {
            throw URLError(.userAuthenticationRequired)
        }

        return .next(
            NextSession(authToken: access)
        )
    }
}
