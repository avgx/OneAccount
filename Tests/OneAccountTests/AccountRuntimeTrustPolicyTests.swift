import Foundation
import Testing
import HTTP
import WS
import SSLPinning
@testable import OneAccount

private func sampleRecord(
    id: AccountID = UUID(),
    policy: ServerTrustPolicy,
    backend: Backend = .next
) -> AccountRecord {
    AccountRecord(
        id: id,
        baseURL: URL(string: "https://example.com")!,
        user: "user",
        password: "secret",
        name: nil,
        backend: backend,
        session: .next(NextSession(authToken: "token")),
        serverTrustPolicy: policy
    )
}

@Test func serverTrustPolicyPersistsInKeychain() async throws {
    let service = "Tests.OneAccount.TrustPolicy.\(UUID().uuidString)"
    let store = AccountStorage.keychain(keyPrefix: "tp", service: service).makeStore()
    let policy: ServerTrustPolicy = .trustEveryone
    let record = sampleRecord(policy: policy)

    try await store.save(record)
    let loaded = try await store.get(by: record.id)
    #expect(loaded?.serverTrustPolicy == policy)

    try await store.deleteAll()
}

@Test func runtimeHTTPClientUsesAccountServerTrustPolicy() async throws {
    let store = AccountStorage.memory.makeStore()
    let factory = DefaultAccountRuntimeFactory(store: store)
    let policy: ServerTrustPolicy = .trustEveryone
    let record = sampleRecord(policy: policy)
    try await store.save(record)

    let runtime = await factory.build(account: record) { _ in }
    #expect(runtime != nil)
    let httpPolicy = await runtime!.http.serverTrustPolicy
    #expect(httpPolicy == policy)
    await runtime?.shutdown()
}

@Test @MainActor
func accountSwitchAppliesEachAccountsServerTrustPolicy() async throws {
    let store = AccountStorage.memory.makeStore()
    let factory = DefaultAccountRuntimeFactory(store: store)
    let current = CurrentAccount(store: store, factory: factory)

    let pinned = sampleRecord(policy: .trustEveryone)
    let system = sampleRecord(policy: .system)
    try await store.save(pinned)
    try await store.save(system)

    await current.selectAccount(id: pinned.id)
    let pinnedHTTPPolicy = await current.runtime?.http.serverTrustPolicy
    let pinnedAccountPolicy = await current.runtime?.account.serverTrustPolicy
    #expect(pinnedHTTPPolicy == .trustEveryone)
    #expect(pinnedAccountPolicy == .trustEveryone)

    await current.selectAccount(id: system.id)
    let systemHTTPPolicy = await current.runtime?.http.serverTrustPolicy
    let systemAccountPolicy = await current.runtime?.account.serverTrustPolicy
    #expect(systemHTTPPolicy == .system)
    #expect(systemAccountPolicy == .system)

    await current.selectAccount(id: nil)
    #expect(current.runtime == nil)
}

@Test func webSocketConfigurationUsesAccountServerTrustPolicy() async throws {
    let store = AccountStorage.memory.makeStore()
    let factory = DefaultAccountRuntimeFactory(store: store)
    let policy: ServerTrustPolicy = .trustEveryone
    let record = sampleRecord(policy: policy)
    try await store.save(record)

    let runtime = await factory.build(account: record) { _ in }
    #expect(runtime != nil)

    let configuration = runtime!.webSocketConfiguration()
    #expect(configuration.serverTrustPolicy == policy)

    let request = URLRequest(url: AccountRuntime.webSocketURL(
        httpURL: URL(string: "https://example.com/events")!
    ))
    _ = await runtime!.makeWebSocket(request: request)

    await runtime?.shutdown()
}
