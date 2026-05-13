import Foundation
import HTTP
import RequestResponse

/// Shared JSON ``HTTPClient`` + ``RequestBuilder`` used by bearer-token session refresh calls.
enum BearerRefreshTransport {
    static func jsonClientAndBuilder(baseURL: URL, bearerToken: String) -> (HTTPClient, RequestBuilder) {
        let client = HTTPClient(
            interceptor: FixedAuthInterceptor(authorization: .bearer(bearerToken))
        )
        let builder = RequestBuilder.json(baseURL: baseURL, encoder: JSONEncoder())
        return (client, builder)
    }
}
