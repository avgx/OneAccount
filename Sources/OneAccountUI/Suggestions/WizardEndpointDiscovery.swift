import Foundation
import OneDiscovery
import OneAccount

/// Resolves a user-entered host/URL to a concrete base URL and ``Backend`` using the same discovery loop as the add-account wizard.
public enum WizardEndpointDiscovery: Sendable {
    public enum DiscoveryFailure: Error, Sendable, LocalizedError {
        case emptyInput
        case noSeeds
        case unsupportedBackend
        case underlying(Error)

        public var errorDescription: String? {
            switch self {
            case .emptyInput, .noSeeds:
                "Enter a server address."
            case .unsupportedBackend:
                "Server not recognized. Check the address."
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
            if error is DiscoveryError {
                return "Server not recognized. Check the address."
            }
            return "Could not connect to server."
        }
    }

    /// Tries each seed from ``URL/endpointDiscoverySeeds(from:)`` in parallel until a known ``Backend`` is found.
    /// Cloud takes precedence and stops further probing.
    public static func resolveEndpoint(trimmedURL: String) async throws -> (url: URL, backend: OneAccount.Backend) {
        let trimmed = trimmedURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw DiscoveryFailure.emptyInput }
        let seeds = URL.endpointDiscoverySeeds(from: trimmed)
        guard !seeds.isEmpty else { throw DiscoveryFailure.noSeeds }

        let session = DiscoveryURLSession.make()

        return try await withThrowingTaskGroup(of: Result<(URL, OneAccount.Backend), Error>.self) { group in
            for seed in seeds {
                group.addTask {
                    do {
                        let discoveries = try await Web.exploreDiscoveries(url: seed, session: session)
                        for discovery in discoveries {
                            guard let backend = OneAccount.Backend(rawValue: discovery.backend.rawValue) else {
                                continue
                            }
                            if backend == .cloud {
                                return .success((discovery.baseURL, backend))
                            }
                        }
                        guard let first = discoveries.first,
                              let backend = OneAccount.Backend(rawValue: first.backend.rawValue)
                        else {
                            return .failure(DiscoveryFailure.unsupportedBackend)
                        }
                        return .success((first.baseURL, backend))
                    } catch {
                        return .failure(error)
                    }
                }
            }

            var lastError: Error?
            var firstSuccess: (URL, OneAccount.Backend)?
            while let outcome = try await group.next() {
                switch outcome {
                case .success(let pair):
                    if pair.1 == .cloud {
                        group.cancelAll()
                        return pair
                    }
                    if firstSuccess == nil {
                        firstSuccess = pair
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
