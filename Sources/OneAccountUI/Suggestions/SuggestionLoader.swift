import Foundation
import OneDiscovery
import OneAccount

/// Debounced discovery for the endpoint URL field. Runs `Web.explore` per seed URL (https/http when scheme is omitted). Ports and path suffixes are handled inside OneDiscovery.
@MainActor
public final class SuggestionLoader: ObservableObject {

    public struct Row: Identifiable, Equatable, Sendable {
        public let id: String
        public let seedURL: URL
        public var phase: Phase

        public enum Phase: Equatable, Sendable {
            case loading
            case succeeded(DiscoveryCandidate)
            case failed(String)
        }
    }

    public static let debounceNanoseconds: UInt64 = 400_000_000

    @Published private(set) public var rows: [Row] = []

    private var generation: Int = 0
    private var debounceTask: Task<Void, Never>?

    public init() {}

    public func scheduleReload(rawURL: String) {
        debounceTask?.cancel()
        generation += 1
        let requestGeneration = generation

        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.debounceNanoseconds)
            guard !Task.isCancelled else { return }
            await self?.reload(rawURL: rawURL, generation: requestGeneration)
        }
    }

    public func cancelPendingWork() {
        debounceTask?.cancel()
        debounceTask = nil
    }

    private func reload(rawURL: String, generation requestGeneration: Int) async {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            if requestGeneration == generation {
                rows = []
            }
            return
        }

        let seeds = URL.endpointDiscoverySeeds(from: trimmed)
        guard !seeds.isEmpty else {
            if requestGeneration == generation {
                rows = []
            }
            return
        }

        if requestGeneration != generation { return }

        rows = seeds.map { Row(id: $0.absoluteString, seedURL: $0, phase: .loading) }

        var results: [String: Row.Phase] = [:]
        await withTaskGroup(of: (String, Row.Phase).self) { group in
            for seed in seeds {
                group.addTask {
                    do {
                        let discovery = try await Web.explore(url: seed, session: .shared)
                        guard let backend = OneAccount.Backend(rawValue: discovery.backend.rawValue) else {
                            return (seed.absoluteString, .failed("unknown backend"))
                        }
                        let endpoint = Endpoint(url: discovery.baseURL, backend: backend)
                        let candidate = DiscoveryCandidate(endpoint: endpoint, summary: discovery.summary)
                        return (seed.absoluteString, .succeeded(candidate))
                    } catch {
                        return (seed.absoluteString, .failed(error.localizedDescription))
                    }
                }
            }
            for await (id, phase) in group {
                results[id] = phase
            }
        }

        guard requestGeneration == generation else { return }

        rows = seeds.map { seed in
            let id = seed.absoluteString
            let phase = results[id] ?? .failed("cancelled")
            return Row(id: id, seedURL: seed, phase: phase)
        }
        .sorted { lhs, rhs in
            switch (lhs.phase, rhs.phase) {
            case (.succeeded, .failed), (.succeeded, .loading):
                return true
            case (.failed, .succeeded), (.loading, .succeeded):
                return false
            default:
                break
            }
            let lhsHttps = lhs.seedURL.scheme?.lowercased() == "https"
            let rhsHttps = rhs.seedURL.scheme?.lowercased() == "https"
            if lhsHttps != rhsHttps { return lhsHttps }
            return lhs.id < rhs.id
        }
    }
}
