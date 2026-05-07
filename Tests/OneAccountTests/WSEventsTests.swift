import Foundation
import Testing
import HTTP
import WS
import RequestResponse
import JWTDecode
import DebugThings
import Logging
@testable import OneAccount

/// Requires: `NEXT_URL`, `NEXT_USER`, `NEXT_PASSWORD` (omit `.env` in CI to skip meaningful run).
/// POST `v1/authentication/authenticate_ex2` … then WebSocket `events` with Bearer via ``AuthInterceptor``;
/// refresh via `renew2`, disconnect, reconnect — second handshake must use the new token.
@Test func readWSEventsWithTokenRefresh() async throws {
    let env = DotEnv.merged
    guard let urlString = env["NEXT_URL"], !urlString.isEmpty, let url = URL(string: urlString),
          let user = env["NEXT_USER"], !user.isEmpty,
          let password = env["NEXT_PASSWORD"], !password.isEmpty
    else {
        Issue.record("Set NEXT_URL, NEXT_USER, NEXT_PASSWORD in .env to run this test.")
        return
    }
    DebugThings.bootstrapOSLog(level: .debug)
    let builder = RequestBuilder.json(baseURL: url, encoder: JSONEncoder())
    let authClient = HTTPClient(
        observer: LoggingRequestObserver(logger: Logger(label: "auth")),
    )

    let authenticateResult = try await authClient.send(NextApi.authenticate(user: user, password: password), with: builder)
    #expect(authenticateResult.value.error_code == .AUTHENTICATE_CODE_OK)
    #expect(authenticateResult.value.token_name == "auth_token")
    #expect(authenticateResult.value.token_value != nil)
    let jwt = authenticateResult.value.token_value!
    let decoded = try decode(jwt: jwt)
    #expect(decoded.expiresAt != nil)
    #expect(decoded.expiresAt! > Date())

    let auth = Auth(policy: .init(margin: 60), refresher: NextSessionRefresher(baseURL: url))
    await auth.setSession(.next(.init(authToken: jwt)))

    var configuration = WebSocket.Configuration.default
    configuration.serverTrustPolicy = .system
    configuration.connectionHandshakeTimeout = 25

    let eventsUrl = try webSocketURL(builder: builder, path: "events")
    let request = URLRequest(url: eventsUrl)

    let socket = WebSocket(request: request, configuration: configuration, requestAdapter: AuthInterceptor(auth: auth))

    let stream1 = await socket.messages()

    let stateTask = Task {
        let stateStream = await socket.connectionStateUpdates()
        for await state in stateStream {
            print("[WS] state: \(String(describing: state))")
        }
    }
    defer { stateTask.cancel() }

    await socket.connect()
    guard await webSocketReachedConnected(socket) else { return }

    let first = await firstWebSocketMessage(in: stream1)
    #expect(first != nil, "No WebSocket message before refresh (events stream idle?).")

    print("first message \(String(describing: first))")
    
    let tokenAfterRefresh = try await auth.refresh()
    #expect(tokenAfterRefresh != jwt, "renew2 should issue a new access token string.")
    print("tokenAfterRefresh \(tokenAfterRefresh)")

    await socket.disconnect()
    print("after disconnect")
    
    try? await Task.sleep(nanoseconds: NSEC_PER_SEC)
    print("after sleep")
    
    let stream2 = await socket.messages()
    await socket.connect()
    guard await webSocketReachedConnected(socket) else { return }

    let second = await firstWebSocketMessage(in: stream2)
    #expect(second != nil, "No WebSocket message after reconnect with refreshed token.")
    print("second message \(String(describing: second))")
    
    await socket.disconnect()
    print("after 2 disconnect")
}

private func webSocketReachedConnected(_ socket: WebSocket) async -> Bool {
    let state = await socket.connectionState()
    guard case .connected = state else {
        if case let .disconnected(reason) = state {
            Issue.record("WebSocket did not connect: \(String(describing: reason))")
        } else {
            Issue.record("WebSocket did not reach connected state: \(String(describing: state))")
        }
        await socket.disconnect()
        return false
    }
    return true
}

/// Same path as HTTP GET against `builder`, with scheme `http`→`ws` / `https`→`wss`.
private func webSocketURL(builder: RequestBuilder, path: String) throws -> URL {
    let httpURL = try builder.url(for: Request(path: path, method: .get))
    guard var components = URLComponents(url: httpURL, resolvingAgainstBaseURL: false) else {
        return httpURL
    }
    if let scheme = components.scheme?.lowercased() {
        components.scheme = scheme.replacingOccurrences(of: "http", with: "ws")
    }
    return components.url ?? httpURL
}

private func firstWebSocketMessage(
    in stream: AsyncStream<URLSessionWebSocketTask.Message>,
    timeoutNanoseconds: UInt64 = 30_000_000_000
) async -> URLSessionWebSocketTask.Message? {
    await withTaskGroup(of: URLSessionWebSocketTask.Message?.self) { group in
        group.addTask {
            for await message in stream {
                return message
            }
            return nil
        }
        group.addTask {
            try? await Task.sleep(nanoseconds: timeoutNanoseconds)
            return nil
        }
        guard let winner = await group.next() else {
            group.cancelAll()
            return nil
        }
        group.cancelAll()
        return winner
    }
}
