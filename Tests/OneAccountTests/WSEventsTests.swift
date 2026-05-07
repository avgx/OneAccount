import Foundation
import Testing
import HTTP
import WS
import RequestResponse
import JWTDecode
import DebugThings
import Logging
@testable import OneAccount

/// Requires: `NEXT_URL`, `NEXT_USER`, `NEXT_PASSWORD`
/// Request:
/// POST `v1/authentication/authenticate_ex2` with `{"user_name":"...","password":"..."}`
/// Response: 200
/// `{"error_code":"AUTHENTICATE_CODE_OK","token_name":"auth_token","token_value":"...", ...}`
/// Refresh in 5 minutes or faster with `v1/authentication/renew2`
@Test func readWSEventsWithTokenRefresh() async throws {
    let env = DotEnv.merged
    guard let urlString = env["NEXT_URL"], !urlString.isEmpty, let url = URL(string: urlString),
          let user = env["NEXT_USER"], !user.isEmpty,
          let password = env["NEXT_PASSWORD"], !password.isEmpty,
          let clientIdPrefix = env["CLIENT_ID_PREFIX"], !clientIdPrefix.isEmpty
    else {
        Issue.record("Set NEXT_URL, NEXT_USER, NEXT_PASSWORD, CLIENT_ID_PREFIX in .env to run this test.")
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
    
    print(authenticateResult.value.token_value ?? "no token")
    
    let auth = Auth(policy: .init(margin: 290), refresher: NextSessionRefresher(baseURL: url))
    await auth.setSession(.next(.init(authToken: jwt)))
    
    
    let client = HTTPClient(
        configuration: .ephemeral,
        interceptor: AuthInterceptor(auth: auth),
        observer: LoggingRequestObserver(),
        logger: SimpleURLSessionTaskLogger(label: "work", logReceiveData: true)
    )
    
    var configuration = WebSocket.Configuration.default
    configuration.serverTrustPolicy = .system
    configuration.connectionHandshakeTimeout = 25
    
    //TODO: это выглядит очень некрасиво!
    var eventsUrl = try builder.url(for: Request(path: "events", method: .get))
    var eventsUrlComponents = URLComponents(url: eventsUrl, resolvingAgainstBaseURL: false)
    eventsUrlComponents?.scheme = eventsUrl.scheme?.replacingOccurrences(of: "http", with: "ws")
    eventsUrl = eventsUrlComponents?.url ?? eventsUrl
    var request = URLRequest(url: eventsUrl)
    request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
    
    let socket = WebSocket(request: request, configuration: configuration)
    
    let stream = await socket.messages()

    let stateTask = Task {
        let stateStream = await socket.connectionStateUpdates()
        for await state in stateStream {
            print("[WS long listen] state: \(String(describing: state))")
        }
    }
    defer { stateTask.cancel() }

    await socket.connect()
    let state = await socket.connectionState()
    guard case .connected = state else {
        if case let .disconnected(reason) = state {
            Issue.record("WebSocket did not connect: \(String(describing: reason))")
        } else {
            Issue.record("WebSocket did not reach connected state: \(String(describing: state))")
        }
        await socket.disconnect()
        return
    }

    let tenMinutesNanos: UInt64 = 600 * 1_000_000_000
    await withTaskGroup(of: Void.self) { group in
        group.addTask {
            for await message in stream {
                print("ws \(message)")
            }
        }
        group.addTask {
            try? await Task.sleep(nanoseconds: tenMinutesNanos)
        }
        await group.next()
        group.cancelAll()
    }

    await socket.disconnect()
//
//    var i = 0
//    while true {
//        do {
//            try await Task.sleep(nanoseconds: 1_000_000_000)
//            let res = try await client.send(NextApi.test(), with: builder)
//            
//            print("\(Date()) \(String(describing: res.statusCode))")
//            i += 1
//            if i > 20 {
//                break
//            }
//        } catch {
//            print("\(error) - \(error.localizedDescription)")
//        }
//    }
//    
//    _ = try await client.send(NextApi.close(), with: builder)
}
