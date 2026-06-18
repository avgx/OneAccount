import Foundation
import HTTP
import WS
import SSLPinning

extension AccountRuntime {
    /// WebSocket configuration using this account's persisted TLS policy.
    public nonisolated func webSocketConfiguration(
        _ base: WebSocket.Configuration = .default
    ) -> WebSocket.Configuration {
        var configuration = base
        configuration.serverTrustPolicy = account.serverTrustPolicy
        return configuration
    }

    /// Builds a ``WebSocket`` with ``account`` TLS policy and optional bearer auth from ``auth``.
    public func makeWebSocket(
        request: URLRequest,
        configuration: WebSocket.Configuration = .default,
        requestAdapter: (any RequestAdapter)? = nil
    ) -> WebSocket {
        let adapter: any RequestAdapter
        if let requestAdapter {
            adapter = requestAdapter
        } else if let auth {
            adapter = AuthInterceptor(auth: auth)
        } else {
            adapter = NoopRequestInterceptor()
        }
        return WebSocket(
            request: request,
            configuration: webSocketConfiguration(configuration),
            requestAdapter: adapter
        )
    }

    /// Converts an HTTP URL (same host/path as REST) to `ws` / `wss`.
    public nonisolated static func webSocketURL(httpURL: URL) -> URL {
        guard var components = URLComponents(url: httpURL, resolvingAgainstBaseURL: false) else {
            return httpURL
        }
        if let scheme = components.scheme?.lowercased() {
            components.scheme = scheme.replacingOccurrences(of: "http", with: "ws")
        }
        return components.url ?? httpURL
    }
}
