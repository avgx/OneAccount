import Foundation

/// Универсальный мультикаст-хаб: несколько подписчиков получают каждое опубликованное значение.
actor Hub<T: Sendable> {
    private struct Subscription {
        let id: UUID
        let continuation: AsyncStream<T>.Continuation
    }

    private var subscriptions: [Subscription] = []

    public func subscribe() -> AsyncStream<T> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<T>.makeStream()
        continuation.onTermination = { @Sendable _ in
            Task { await self.remove(id: id) }
        }
        subscriptions.append(Subscription(id: id, continuation: continuation))
        return stream
    }

    public func publish(_ event: T) {
        for sub in subscriptions {
            sub.continuation.yield(event)
        }
    }

    private func remove(id: UUID) {
        subscriptions.removeAll { $0.id == id }
    }
}
