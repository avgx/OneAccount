import Foundation
import HTTP
import SSLPinning
import Testing
@testable import OneAccount
@testable import OneAccountUI

private struct ProbeFailure: Error {}

private final class ExactDiscovery: @unchecked Sendable {
    private let lock = NSLock()
    private var callCount = 0
    var outcome: Result<DiscoveredEndpoint, Error>

    init(_ outcome: Result<DiscoveredEndpoint, Error>) {
        self.outcome = outcome
    }

    var calls: Int {
        lock.lock()
        defer { lock.unlock() }
        return callCount
    }

    func noteCall() throws -> DiscoveredEndpoint {
        lock.lock()
        callCount += 1
        let outcome = self.outcome
        lock.unlock()
        return try outcome.get()
    }

    func client() -> DiscoveryClient {
        DiscoveryClient(
            policy: .all,
            exploreDiscoveries: { _, _, _ in [] },
            exploreExact: { [self] _, _, _ in
                try self.noteCall()
            }
        )
    }
}

private func account(backend: Backend?, url: String = "https://old.example/") -> AccountRecord {
    AccountRecord(
        baseURL: URL(string: url)!,
        user: "user",
        password: "secret",
        backend: backend
    )
}

private func discovered(_ backend: Backend, url: String = "https://old.example/") -> DiscoveredEndpoint {
    DiscoveredEndpoint(
        url: URL(string: url)!,
        backend: backend,
        name: "server",
        summary: "summary"
    )
}

private func httpError(status: Int) -> HTTPError {
    HTTPError.unacceptableStatusCode(
        statusCode: status,
        body: Data(),
        url: URL(string: "https://old.example/")
    )
}

@Test func checkIfMoved_cloudDoesNotDiscover() async {
    let discovery = ExactDiscovery(.failure(ProbeFailure()))
    let show = await account(backend: .cloud).endpoint.checkIfMoved(
        error: URLError(.cannotConnectToHost),
        discovery: discovery.client()
    )
    #expect(show == false)
    #expect(discovery.calls == 0)
}

@Test func checkIfMoved_offlineDoesNotDiscover() async {
    let codes: [URLError.Code] = [
        .notConnectedToInternet,
        .networkConnectionLost,
        .dataNotAllowed,
        .internationalRoamingOff,
        .cancelled,
    ]
    for code in codes {
        let discovery = ExactDiscovery(.failure(ProbeFailure()))
        let show = await account(backend: .next).endpoint.checkIfMoved(
            error: URLError(code),
            discovery: discovery.client()
        )
        #expect(show == false)
        #expect(discovery.calls == 0)
    }

    let discovery = ExactDiscovery(.failure(ProbeFailure()))
    let show = await account(backend: .intl).endpoint.checkIfMoved(
        error: CancellationError(),
        discovery: discovery.client()
    )
    #expect(show == false)
    #expect(discovery.calls == 0)
}

@Test func checkIfMoved_authenticationDoesNotDiscover() async {
    let errors: [Error] = [
        httpError(status: 401),
        URLError(.userAuthenticationRequired),
        AuthServiceError.nextAuthRejected(code: .AUTHENTICATE_CODE_PASSWORD_INVALID, detail: nil),
    ]
    for error in errors {
        let discovery = ExactDiscovery(.failure(ProbeFailure()))
        let show = await account(backend: .nextLegacy).endpoint.checkIfMoved(
            error: error,
            discovery: discovery.client()
        )
        #expect(show == false)
        #expect(discovery.calls == 0)
    }
}

@Test func checkIfMoved_pinningDoesNotDiscover() async {
    let discovery = ExactDiscovery(.failure(ProbeFailure()))
    let show = await account(backend: .next).endpoint.checkIfMoved(
        error: SSLPinningError.invalidServerTrust(host: "old.example"),
        discovery: discovery.client()
    )
    #expect(show == false)
    #expect(discovery.calls == 0)
}

@Test func checkIfMoved_unreachableHostWhenDiscoveryCannotConnect() async {
    let codes: [URLError.Code] = [
        .cannotFindHost,
        .dnsLookupFailed,
        .cannotConnectToHost,
        .timedOut,
    ]
    for code in codes {
        let discovery = ExactDiscovery(.failure(URLError(.cannotConnectToHost)))
        let show = await account(backend: .intl).endpoint.checkIfMoved(
            error: URLError(code),
            discovery: discovery.client()
        )
        #expect(show == true)
        #expect(discovery.calls == 1)
    }
}

@Test func checkIfMoved_expectedBackendHidesButton() async {
    let discovery = ExactDiscovery(.success(discovered(.next)))
    let show = await account(backend: .next).endpoint.checkIfMoved(
        error: httpError(status: 502),
        discovery: discovery.client()
    )
    #expect(show == false)
    #expect(discovery.calls == 1)
}

@Test func checkIfMoved_differentBackendShowsButton() async {
    let discovery = ExactDiscovery(.success(discovered(.intl)))
    let show = await account(backend: .next).endpoint.checkIfMoved(
        error: httpError(status: 404),
        discovery: discovery.client()
    )
    #expect(show == true)
}

@Test func checkIfMoved_unrecognizedServiceShowsButton() async {
    let discovery = ExactDiscovery(.failure(ProbeFailure()))
    let show = await account(backend: .nextLegacy).endpoint.checkIfMoved(
        error: httpError(status: 404),
        discovery: discovery.client()
    )
    #expect(show == true)
    #expect(discovery.calls == 1)
}

@Test func checkIfMoved_discoveryOfflineHidesButton() async {
    let discovery = ExactDiscovery(.failure(URLError(.notConnectedToInternet)))
    let show = await account(backend: .next).endpoint.checkIfMoved(
        error: httpError(status: 502),
        discovery: discovery.client()
    )
    #expect(show == false)
    #expect(discovery.calls == 1)
}

@Test func checkIfMoved_onlineTimeoutWithUnavailableRadioDoesNotDiscover() async {
    let nsError = NSError(
        domain: NSURLErrorDomain,
        code: URLError.timedOut.rawValue,
        userInfo: [
            NSURLErrorNetworkUnavailableReasonKey: NSNumber(
                value: URLError.NetworkUnavailableReason.cellular.rawValue
            ),
        ]
    )
    let error = URLError(_nsError: nsError)
    let discovery = ExactDiscovery(.failure(ProbeFailure()))
    let show = await account(backend: .next).endpoint.checkIfMoved(
        error: error,
        discovery: discovery.client()
    )
    #expect(error.networkUnavailableReason == .cellular)
    #expect(show == false)
    #expect(discovery.calls == 0)
}

@Test func endpointChange_rejectsCloudAndDifferentBackend() throws {
    let next = account(backend: .next)
    let url = URL(string: "https://10.0.0.8/")!
    #expect(try EndpointChange.canonicalURL(account: next, url: url, backend: .next) == url)
    #expect(throws: ChangeEndpointFailure.differentBackend) {
        try EndpointChange.canonicalURL(account: next, url: url, backend: .intl)
    }
    #expect(throws: ChangeEndpointFailure.unsupportedAccount) {
        try EndpointChange.canonicalURL(account: account(backend: .cloud), url: url, backend: .cloud)
    }
}

@Test func endpointChange_resolveKeepsMatchingBackendURL() async throws {
    let canonical = URL(string: "https://10.0.0.8/client/")!
    let discovery = ExactDiscovery(.success(discovered(.next, url: canonical.absoluteString)))
    let url = try await EndpointChange.resolve(
        trimmedURL: "10.0.0.8",
        account: account(backend: .next),
        discovery: discovery.client(),
        session: URLSession(configuration: .ephemeral)
    )
    #expect(url == canonical)
}

@Test func endpointChange_resolveRejectsForeignBackend() async {
    let discovery = ExactDiscovery(.success(discovered(.intl, url: "https://10.0.0.8/")))
    await #expect(throws: ChangeEndpointFailure.differentBackend) {
        try await EndpointChange.resolve(
            trimmedURL: "https://10.0.0.8/",
            account: account(backend: .next),
            discovery: discovery.client(),
            session: URLSession(configuration: .ephemeral)
        )
    }
}

@Test func updateEndpoint_keepsBackendPasswordAndPin() async throws {
    let store = AccountStorage.memory.makeStore()
    let pin = Fingerprint(host: "old.example", spkiSHA256: String(repeating: "ab", count: 32))
    let policy = ServerTrustPolicy.pinningSpki([pin])
    let record = AccountRecord(
        baseURL: URL(string: "https://old.example/")!,
        user: "user",
        password: "secret",
        name: "desk",
        backend: .next,
        session: .next(NextSession(authToken: "token")),
        serverTrustPolicy: policy
    )
    try await store.save(record)

    let moved = URL(string: "https://10.0.0.8/")!
    try await store.updateEndpoint(accountID: record.id, url: moved)

    let loaded = try await store.get(by: record.id)
    #expect(loaded?.endpoint.url == moved)
    #expect(loaded?.endpoint.backend == .next)
    #expect(loaded?.credentials.password == "secret")
    #expect(loaded?.credentials.user == "user")
    #expect(loaded?.serverTrustPolicy == policy)
    #expect(loaded?.session == record.session)
    #expect(loaded?.profile.name == "desk")
}

@Test func updateEndpoint_missingAccountThrows() async {
    let store = AccountStorage.memory.makeStore()
    let id = UUID()
    do {
        try await store.updateEndpoint(accountID: id, url: URL(string: "https://10.0.0.8/")!)
        Issue.record("expected accountNotFound")
    } catch let PersistenceError.accountNotFound(found) {
        #expect(found == id)
    } catch {
        Issue.record("unexpected error \(error)")
    }
}
