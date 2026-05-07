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
    let manager = AccountStorage.userDefaults(keyPrefix: prefix).makeManager()

    let record = sampleRecord()
    try await manager.save(record)
    try await manager.loadIfNeeded()
    let loaded = try await manager.get(record.id)
    #expect(loaded?.id == record.id)
    #expect(loaded?.user == record.user)

    try await manager.deleteAll()
}

@Test func securePersistenceRoundTrip() async throws {
    let service = "Tests.OneAccount.Keychain.\(UUID().uuidString)"
    let prefix = "Kc"
    let manager = AccountStorage.keychain(keyPrefix: prefix, service: service).makeManager()

    let a = sampleRecord()
    let b = sampleRecord()

    try await manager.save(a)
    try await manager.save(b)

    let ids = try await manager.getAllIDs()
    #expect(Set(ids) == [a.id, b.id])

    try await manager.delete(a.id)
    #expect(try await manager.getAllIDs() == [b.id])

    try await manager.deleteAll()
    #expect(try await manager.getAllIDs().isEmpty)
}

@Test func accountStorageMemoryHasNoPersistence() async throws {
    let manager = AccountStorage.memory.makeManager()
    let id = UUID()
    try await manager.save(sampleRecord(id: id))
    #expect(try await manager.get(id) != nil)
    await manager.clearCache()
    try await manager.load()
    #expect(try await manager.get(id) == nil)
}
