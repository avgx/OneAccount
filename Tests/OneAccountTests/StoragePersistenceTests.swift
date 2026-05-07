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

@Test func userDefaultsPersistenceRoundTrip() throws {
    let prefix = "OA.UD.\(UUID().uuidString)"
    let p = UserDefaultsPersistence(keyPrefix: prefix)
    defer {
        try? p.deleteAll()
    }

    let a = sampleRecord()
    let b = sampleRecord()

    try p.save(account: a)
    try p.save(account: b)

    let ids = try p.getAllIDs().sorted { $0.uuidString < $1.uuidString }
    #expect(Set(ids) == [a.id, b.id])

    let all = try p.loadAll()
    #expect(all.count == 2)

    #expect(try p.exists(accountID: a.id))
    try p.delete(accountID: a.id)
    #expect(try p.load(accountID: a.id) == nil)
    #expect(try p.getAllIDs() == [b.id])

    try p.deleteAll()
    #expect(try p.getAllIDs().isEmpty)
}

@Test func accountStorageFactoryUserDefaults() async throws {
    let prefix = "OA.F.\(UUID().uuidString)"
    let store = AccountStorage.userDefaults(keyPrefix: prefix).makeStore()

    let record = sampleRecord()
    try await store.save(record)
    try await store.loadIfNeeded()
    let loaded = try await store.get(record.id)
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
    #expect(try await store.get(id) != nil)
    await store.clearCache()
    try await store.load()
    #expect(try await store.get(id) == nil)
}
