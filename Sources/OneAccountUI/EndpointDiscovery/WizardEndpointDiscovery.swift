import Foundation
import OneAccount

/// Resolves a user-entered host/URL using an injected ``DiscoveryClient``.
public enum WizardEndpointDiscovery: Sendable {
    public enum DiscoveryFailure: Error, Sendable, LocalizedError {
        case emptyInput
        case noSeeds
        case unsupportedBackend
        case disallowedBackend
        case underlying(Error)

        public var errorDescription: String? {
            switch self {
            case .emptyInput, .noSeeds:
                "Enter a server address."
            case .unsupportedBackend:
                "Server not recognized. Check the address."
            case .disallowedBackend:
                "This app does not support that type of server."
            case .underlying(let error):
                Self.message(for: error)
            }
        }

        private static func message(for error: Error) -> String {
            if let failure = error as? DiscoveryFailure {
                return failure.errorDescription ?? "Could not connect to server."
            }
            if let localized = error as? LocalizedError,
               let description = localized.errorDescription,
               !description.isEmpty {
                return description
            }
            if let urlError = error as? URLError {
                switch urlError.code {
                case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                    return "Cannot reach server."
                case .timedOut:
                    return "The connection timed out."
                case .notConnectedToInternet, .networkConnectionLost:
                    return "No internet connection."
                default:
                    break
                }
                return urlError.localizedDescription
            }
            return "Could not connect to server."
        }
    }

    /// Tries each seed from ``URL/endpointDiscoverySeeds(from:)`` in parallel until a known ``Backend`` is found.
    /// Cloud takes precedence and stops further probing.
    public static func resolveEndpoint(
        trimmedURL: String,
        discovery: DiscoveryClient,
        session: URLSession
    ) async throws -> ResolvedEndpoint {
        let trimmed = trimmedURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw DiscoveryFailure.emptyInput }
        let seeds = URL.endpointDiscoverySeeds(from: trimmed)
        guard !seeds.isEmpty else { throw DiscoveryFailure.noSeeds }

        let policy = discovery.policy

        return try await withThrowingTaskGroup(of: Result<ResolvedEndpoint, Error>.self) { group in
            for seed in seeds {
                group.addTask {
                    do {
                        let discoveries = try await discovery.exploreDiscoveries(seed, session, policy)
                        let allowed = discoveries.filter { policy.allows($0.backend) }
                        for item in allowed where item.backend == .cloud {
                            return .success(ResolvedEndpoint(url: item.url, backend: item.backend, name: item.name))
                        }
                        guard let first = allowed.first else {
                            if !discoveries.isEmpty {
                                return .failure(DiscoveryFailure.disallowedBackend)
                            }
                            return .failure(DiscoveryFailure.unsupportedBackend)
                        }
                        return .success(ResolvedEndpoint(url: first.url, backend: first.backend, name: first.name))
                    } catch {
                        return .failure(error)
                    }
                }
            }

            var lastError: Error?
            var firstSuccess: ResolvedEndpoint?
            while let outcome = try await group.next() {
                switch outcome {
                case .success(let resolved):
                    if resolved.backend == .cloud {
                        group.cancelAll()
                        return resolved
                    }
                    if firstSuccess == nil {
                        firstSuccess = resolved
                    }
                case .failure(let error):
                    lastError = error
                }
            }

            if let firstSuccess {
                return firstSuccess
            }
            if let lastError {
                throw DiscoveryFailure.underlying(lastError)
            }
            throw DiscoveryFailure.unsupportedBackend
        }
    }
}
