import Foundation

/// Type-erased error storage for wizard step state (`Sendable` for cross-actor flow state).
public struct FlowFailure: Sendable {
    private final class Storage: @unchecked Sendable {
        let error: Error
        init(_ error: Error) { self.error = error }
    }

    private let storage: Storage

    public init(_ error: Error) {
        storage = Storage(error)
    }

    public var error: Error { storage.error }
}
