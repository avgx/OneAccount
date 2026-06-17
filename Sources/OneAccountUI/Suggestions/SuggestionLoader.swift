import Foundation
import OneDiscovery
import OneAccount
import URLKit
import DebugThings

/// Debounced discovery for the endpoint URL field. Typed input uses ``Web/exploreDiscoveries``; static preset URLs use ``Web/exploreExact``.
@MainActor
public final class SuggestionLoader: ObservableObject, Loggable {

    public typealias DemoCredentialsValidator = @Sendable (AccountCredentialsRequest) async -> Bool

    public struct Row: Identifiable, Equatable, Sendable {
        public enum Source: Equatable, Sendable {
            case typed
            case proposed(seedURL: URL)
            case demo(seedURL: URL)
        }

        public let candidate: DiscoveryCandidate
        public let source: Source

        public var id: String {
            switch source {
            case .typed:
                candidate.id
            case .proposed(let seedURL):
                "proposed-\(seedURL.removingCredentials().absoluteString)-\(candidate.id)"
            case .demo(let seedURL):
                "demo-\(seedURL.removingCredentials().absoluteString)-\(candidate.id)"
            }
        }

        public var seedURL: URL? {
            switch source {
            case .typed:
                nil
            case .proposed(let url), .demo(let url):
                url
            }
        }

        public var isDemo: Bool {
            if case .demo = source { return true }
            return false
        }
    }

    public static let debounceNanoseconds: UInt64 = 400_000_000
    public static let discoveryBudgetNanoseconds: UInt64 = 10_000_000_000

    @Published private(set) public var rows: [Row] = []
    @Published private(set) public var proposedRows: [Row] = []
    @Published private(set) public var demoRows: [Row] = []
    @Published private(set) public var isDiscovering = false

    private let session: URLSession
    private let validateDemoCredentials: DemoCredentialsValidator?
    private var generation: Int = 0
    private var debounceTask: Task<Void, Never>?
    private var exploreTask: Task<Void, Never>?

    public init(
        session: URLSession? = nil,
        validateDemoCredentials: DemoCredentialsValidator? = nil
    ) {
        self.session = session ?? DiscoveryURLSession.make()
        self.validateDemoCredentials = validateDemoCredentials
    }

    public func scheduleReload(rawURL: String) {
        logger.info("schedule typed reload: \(rawURL)")
        debounceTask?.cancel()
        generation += 1
        let requestGeneration = generation

        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.debounceNanoseconds)
            guard !Task.isCancelled else { return }
            await self?.reloadTyped(rawURL: rawURL, generation: requestGeneration)
        }
    }

    public func scheduleStaticReload(proposedURLs: [URL], demoURLs: [URL]) {
        logger.info("schedule static reload: proposed=\(proposedURLs.count) demo=\(demoURLs.count)")
        debounceTask?.cancel()
        generation += 1
        let requestGeneration = generation

        exploreTask?.cancel()
        rows = []
        proposedRows = []
        demoRows = []
        isDiscovering = true

        exploreTask = Task { [weak self] in
            guard let self else { return }
            await self.runStaticExplores(
                proposedURLs: proposedURLs,
                demoURLs: demoURLs,
                generation: requestGeneration
            )
        }
    }

    public func cancelPendingWork() {
        logger.info("cancel pending explore")
        debounceTask?.cancel()
        debounceTask = nil
        exploreTask?.cancel()
        exploreTask = nil
        isDiscovering = false
    }

    private func reloadTyped(rawURL: String, generation requestGeneration: Int) async {
        exploreTask?.cancel()
        proposedRows = []
        demoRows = []

        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            if requestGeneration == generation {
                rows = []
                isDiscovering = false
            }
            logger.info("typed reload skipped: empty input")
            return
        }

        let seeds = URL.endpointDiscoverySeeds(from: trimmed)
        guard !seeds.isEmpty else {
            if requestGeneration == generation {
                rows = []
                isDiscovering = false
            }
            logger.info("typed reload skipped: no seeds")
            return
        }

        guard requestGeneration == generation else { return }

        rows = []
        isDiscovering = true
        logger.info("typed explore start: seeds=\(seeds.count)")

        exploreTask = Task { [weak self] in
            guard let self else { return }
            await self.runExplores(seeds: seeds, source: .typed, generation: requestGeneration)
        }
        await exploreTask?.value
    }

    private func runStaticExplores(
        proposedURLs: [URL],
        demoURLs: [URL],
        generation requestGeneration: Int
    ) async {
        defer {
            if requestGeneration == generation {
                isDiscovering = false
            }
        }

        let deadline = DispatchTime.now().uptimeNanoseconds + Self.discoveryBudgetNanoseconds
        let proposedCollector = StaticRowCollector()
        let demoCollector = StaticRowCollector()

        await withTaskGroup(of: (Bool, [Row]).self) { group in
            for url in proposedURLs {
                let source = Row.Source.proposed(seedURL: url)
                group.addTask { [session] in
                    let rows = await self.exploreStaticSeed(
                        url,
                        source: source,
                        generation: requestGeneration,
                        deadline: deadline,
                        session: session
                    )
                    return (false, rows)
                }
            }
            for url in demoURLs {
                let source = Row.Source.demo(seedURL: url)
                group.addTask { [session] in
                    let rows = await self.exploreStaticSeed(
                        url,
                        source: source,
                        generation: requestGeneration,
                        deadline: deadline,
                        session: session
                    )
                    var validated: [Row] = []
                    for row in rows {
                        if await self.validateDemoRow(row, seedURL: url) {
                            validated.append(row)
                        }
                    }
                    return (true, validated)
                }
            }

            for await (isDemo, rows) in group {
                guard requestGeneration == generation else { continue }
                if isDemo {
                    await demoCollector.append(rows)
                    demoRows = await demoCollector.sortedRows()
                } else {
                    await proposedCollector.append(rows)
                    proposedRows = await proposedCollector.sortedRows()
                }
            }
        }

        guard requestGeneration == generation else {
            logger.info("static explore finished: cancelled generation mismatch")
            return
        }
        proposedRows = await proposedCollector.sortedRows()
        demoRows = await demoCollector.sortedRows()
        logger.info("static explore finished: proposed=\(proposedRows.count) demo=\(demoRows.count)")
    }

    private func exploreStaticSeed(
        _ seedURL: URL,
        source: Row.Source,
        generation requestGeneration: Int,
        deadline: UInt64,
        session: URLSession
    ) async -> [Row] {
        guard requestGeneration == generation, !Task.isCancelled else { return [] }
        guard DispatchTime.now().uptimeNanoseconds <= deadline else { return [] }

        let configuredURL = seedURL.removingCredentials()
        logger.info("static seed probe start: \(configuredURL.absoluteString)")

        let discovery: DiscoveryResult
        do {
            discovery = try await Web.exploreExact(url: configuredURL, session: session)
        } catch {
            logger.info("static seed probe failed: \(configuredURL.absoluteString)")
            return []
        }

        guard requestGeneration == generation, !Task.isCancelled else { return [] }
        guard let backend = OneAccount.Backend(rawValue: discovery.backend.rawValue) else { return [] }

        let candidate = DiscoveryCandidate(
            endpoint: Endpoint(url: configuredURL, backend: backend),
            summary: discovery.summary
        )
        logger.info("static seed probe finished: \(configuredURL.absoluteString) backend=\(backend.rawValue)")
        return [Row(candidate: candidate, source: source)]
    }

    private func runExplores(
        seeds: [URL],
        source: Row.Source,
        generation requestGeneration: Int
    ) async {
        defer {
            if requestGeneration == generation {
                isDiscovering = false
            }
        }

        let deadline = DispatchTime.now().uptimeNanoseconds + Self.discoveryBudgetNanoseconds
        let merge = DiscoveryMergeState(source: source)

        await withTaskGroup(of: Bool.self) { group in
            for seed in seeds {
                group.addTask { [session] in
                    guard !Task.isCancelled else { return false }
                    guard DispatchTime.now().uptimeNanoseconds <= deadline else { return false }
                    if await merge.shouldStop { return false }

                    self.logger.info("typed seed explore start: \(seed.absoluteString)")
                    let discoveries: [DiscoveryResult]
                    do {
                        discoveries = try await Web.exploreDiscoveries(url: seed, session: session)
                    } catch {
                        self.logger.info("typed seed explore failed: \(seed.absoluteString)")
                        return false
                    }

                    self.logger.info("typed seed explore finished: \(seed.absoluteString) count=\(discoveries.count)")

                    for discovery in discoveries {
                        guard !Task.isCancelled else { return true }
                        let stop = await merge.absorb(discovery)
                        let currentRows = await merge.sortedRows()
                        await MainActor.run {
                            if requestGeneration == self.generation {
                                self.rows = currentRows
                            }
                        }
                        if stop { return true }
                    }
                    return false
                }
            }

            for await shouldStop in group {
                if shouldStop {
                    group.cancelAll()
                    break
                }
            }
        }

        guard requestGeneration == generation, !Task.isCancelled else {
            logger.info("typed explore finished: cancelled")
            return
        }
        rows = await merge.sortedRows()
        logger.info("typed explore finished: rows=\(rows.count)")
    }

    private func validateDemoRow(_ row: Row, seedURL: URL) async -> Bool {
        guard let validateDemoCredentials else { return false }
        guard row.candidate.endpoint.backend != nil else { return false }
        guard let components = URLComponents(url: seedURL, resolvingAgainstBaseURL: false),
              let user = components.user,
              let password = components.password
        else { return false }

        let redacted = seedURL.removingCredentials().absoluteString
        let request = AccountCredentialsRequest(
            endpoint: row.candidate.endpoint,
            user: user,
            password: password
        )

        if await validateDemoCredentials(request) {
            logger.info("demo credential check passed: \(redacted)")
            return true
        }
        logger.info("demo credential check failed: \(redacted)")
        return false
    }
}

/// Collects static rows — one entry per seed result, no dedupe by backend.
private actor StaticRowCollector {
    private var rows: [SuggestionLoader.Row] = []
    private var seenIDs = Set<String>()

    func append(_ newRows: [SuggestionLoader.Row]) {
        for row in newRows where seenIDs.insert(row.id).inserted {
            rows.append(row)
        }
    }

    func sortedRows() -> [SuggestionLoader.Row] {
        rows.sorted { lhs, rhs in
            let lhsCloud = lhs.candidate.endpoint.backend == .cloud
            let rhsCloud = rhs.candidate.endpoint.backend == .cloud
            if lhsCloud != rhsCloud { return lhsCloud }
            let lhsHttps = lhs.candidate.endpoint.url.scheme?.lowercased() == "https"
            let rhsHttps = rhs.candidate.endpoint.url.scheme?.lowercased() == "https"
            if lhsHttps != rhsHttps { return lhsHttps }
            return lhs.id < rhs.id
        }
    }
}

private actor DiscoveryMergeState {
    private var rows: [SuggestionLoader.Row] = []
    private var backends = Set<OneAccount.Backend>()
    private var stopRequested = false
    private let source: SuggestionLoader.Row.Source

    init(source: SuggestionLoader.Row.Source) {
        self.source = source
    }

    var shouldStop: Bool { stopRequested }

    func absorb(_ discovery: DiscoveryResult) -> Bool {
        if stopRequested { return true }

        guard let backend = OneAccount.Backend(rawValue: discovery.backend.rawValue) else {
            return false
        }

        if backend == .cloud {
            let candidate = DiscoveryCandidate(
                endpoint: Endpoint(url: discovery.baseURL, backend: backend),
                summary: discovery.summary
            )
            rows = [SuggestionLoader.Row(candidate: candidate, source: source)]
            backends = [.cloud]
            stopRequested = true
            return true
        }

        guard backends.insert(backend).inserted else { return false }

        let candidate = DiscoveryCandidate(
            endpoint: Endpoint(url: discovery.baseURL, backend: backend),
            summary: discovery.summary
        )
        rows.append(SuggestionLoader.Row(candidate: candidate, source: source))

        if backends.count >= 2 {
            stopRequested = true
            return true
        }
        return false
    }

    func sortedRows() -> [SuggestionLoader.Row] {
        rows.sorted { lhs, rhs in
            let lhsCloud = lhs.candidate.endpoint.backend == .cloud
            let rhsCloud = rhs.candidate.endpoint.backend == .cloud
            if lhsCloud != rhsCloud { return lhsCloud }
            let lhsHttps = lhs.candidate.endpoint.url.scheme?.lowercased() == "https"
            let rhsHttps = rhs.candidate.endpoint.url.scheme?.lowercased() == "https"
            if lhsHttps != rhsHttps { return lhsHttps }
            return lhs.id < rhs.id
        }
    }
}
