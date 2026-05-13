import Foundation
import RequestResponse
import HTTP

extension Backend {
    public func testRequest() -> Request<Void> {
        switch self {
        case .cloud:
            CloudApi.test()
        case .next, .nextLegacy:
            NextApi.test()
        case .intl:
            IntlApi.test()
        }
    }
    
    public func test(url: URL, user: String, password: String, clientId: String) async throws {
        let builder = RequestBuilder.json(baseURL: url, encoder: JSONEncoder())
        
        if self == .cloud {
            let http = HTTPClient()
            _ = try await http.send(
                CloudApi.login(
                    .init(
                        email: user,
                        password: password,
                        locale: Locale.current.identifier,
                        clientId: clientId
                    )
                ),
                with: builder
            )
        } else {
            let http = HTTPClient(
                interceptor: FixedAuthInterceptor(authorization: .basic(.init(user: user, password: password)))
            )
            _ = try await http.send(testRequest(), with: builder)
        }
    }
}
