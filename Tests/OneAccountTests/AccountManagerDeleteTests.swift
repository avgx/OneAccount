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
        session: .next(NextSession(authToken: "test-access-token")),
        serverTrustPolicy: .system
    )
}

@Test @MainActor func accountManagerDeleteInvokesCallback() async throws {
    let store = AccountStorage.memory.makeStore()
    let record = sampleRecord()
    try await store.save(record)

    let deletedID = Locked<AccountID?>(nil)
    let manager = AccountManager(store: store) { id in
        deletedID.value = id
    }

    try await manager.refresh()
    #expect(manager.accounts.map(\.id) == [record.id])

    try await manager.delete(record.id)

    #expect(deletedID.value == record.id)
    #expect(manager.accounts.isEmpty)
}

@Test @MainActor func accountManagerDeleteWithoutCallback() async throws {
    let store = AccountStorage.memory.makeStore()
    let record = sampleRecord()
    try await store.save(record)

    let manager = AccountManager(store: store)
    try await manager.refresh()
    try await manager.delete(record.id)

    #expect(manager.accounts.isEmpty)
}

private final class Locked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: Value

    init(_ value: Value) {
        _value = value
    }

    var value: Value {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _value
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _value = newValue
        }
    }
}
