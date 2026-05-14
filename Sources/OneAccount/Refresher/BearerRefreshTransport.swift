import Foundation
import HTTP
import RequestResponse
import DebugThings

/// Shared JSON ``HTTPClient`` + ``RequestBuilder`` used by bearer-token session refresh calls.
enum BearerRefreshTransport {
    static func jsonClientAndBuilder(
        baseURL: URL,
        bearerToken: String,
        logger: (any URLSessionTaskLogger)?
    ) -> (HTTPClient, RequestBuilder) {
        let client = HTTPClient(
            interceptor: FixedAuthInterceptor(authorization: .bearer(bearerToken)),
            logger: logger ?? NoopURLSessionTaskLogger()
        )
        let builder = RequestBuilder.json(baseURL: baseURL, encoder: JSONEncoder())
        return (client, builder)
    }
}
