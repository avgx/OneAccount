import Foundation
import Testing
@testable import OneAccount

private func sampleRecord(id: AccountID = UUID(), user: String = "user") -> AccountRecord {
    AccountRecord(
        id: id,
        baseURL: URL(string: "https://example.com")!,
        user: user,
        password: "",
        name: nil,
        backend: .next,
        session: .next(NextSession(authToken: "test-access-token"))
    )
}

@Test func accountStorageFactoryKeychain() async throws {
    let service = "Tests.OneAccount.Factory.\(UUID().uuidString)"
    let store = AccountStorage.keychain(keyPrefix: "pfx", service: service).makeStore()

    let record = sampleRecord()
    try await store.save(record)
    try await store.loadIfNeeded()
    let loaded = try await store.get(by: record.id)
    #expect(loaded?.id == record.id)
    #expect(loaded?.user == record.user)

    try await store.deleteAll()
}

@Test func securePersistenceRoundTrip() async throws {
    let service = "Tests.OneAccount.Keychain.\(UUID().uuidString)"
    let prefix = "Kc"
    let store = AccountStorage.keychain(keyPrefix: prefix, service: service).makeStore()

    let a = sampleRecord()
    let b = sampleRecord()

    try await store.save(a)
    try await store.save(b)

    let ids = try await store.getAllIDs()
    #expect(Set(ids) == [a.id, b.id])

    try await store.delete(a.id)
    #expect(try await store.getAllIDs() == [b.id])

    try await store.deleteAll()
    #expect(try await store.getAllIDs().isEmpty)
}

@Test func accountStorageMemoryHasNoPersistence() async throws {
    let store = AccountStorage.memory.makeStore()
    let id = UUID()
    try await store.save(sampleRecord(id: id))
    #expect(try await store.get(by: id) != nil)
    await store.clearCache()
    try await store.load()
    #expect(try await store.get(by: id) == nil)
}
