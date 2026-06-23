import Foundation

public struct DiscoveredEndpoint: Equatable, Sendable {
    public let url: URL
    public let backend: Backend
    public let name: String
    public let summary: String

    public init(url: URL, backend: Backend, name: String, summary: String) {
        self.url = url
        self.backend = backend
        self.name = name
        self.summary = summary
    }
}

public struct DiscoveryPolicy: Sendable, Equatable {
    public var allowedBackends: Set<Backend>

    public init(allowedBackends: Set<Backend>) {
        self.allowedBackends = allowedBackends
    }

    public static var all: Self {
        DiscoveryPolicy(allowedBackends: Set(Backend.allCases))
    }

    public func allows(_ backend: Backend) -> Bool {
        allowedBackends.contains(backend)
    }
}

public struct DiscoveryClient: Sendable {
    public var policy: DiscoveryPolicy
    public var exploreDiscoveries: @Sendable (URL, URLSession, DiscoveryPolicy) async throws -> [DiscoveredEndpoint]
    public var exploreExact: @Sendable (URL, URLSession, DiscoveryPolicy) async throws -> DiscoveredEndpoint

    public init(
        policy: DiscoveryPolicy,
        exploreDiscoveries: @Sendable @escaping (URL, URLSession, DiscoveryPolicy) async throws -> [DiscoveredEndpoint],
        exploreExact: @Sendable @escaping (URL, URLSession, DiscoveryPolicy) async throws -> DiscoveredEndpoint
    ) {
        self.policy = policy
        self.exploreDiscoveries = exploreDiscoveries
        self.exploreExact = exploreExact
    }
}

private struct DiscoveryUnavailableError: Error {}

extension DiscoveryClient {
    /// Inert client for locked endpoint wizard mode (endpoint step hidden).
    public static var noop: DiscoveryClient {
        DiscoveryClient(
            policy: .all,
            exploreDiscoveries: { _, _, _ in [] },
            exploreExact: { _, _, _ in throw DiscoveryUnavailableError() }
        )
    }
}
