import Foundation
import OneDiscovery

/// Resolves a user-entered host/URL to a concrete base URL and ``Backend`` using the same discovery loop as the add-account wizard.
public enum WizardEndpointDiscovery: Sendable {
    public enum DiscoveryFailure: Error, Sendable {
        case emptyInput
        case noSeeds
        case unsupportedBackend
        case underlying(Error)
    }

    /// Tries each seed from ``URL/endpointDiscoverySeeds(from:)`` until `Web.explore` returns a known ``Backend``.
    public static func resolveEndpoint(trimmedURL: String) async throws -> (url: URL, backend: Backend) {
        let trimmed = trimmedURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw DiscoveryFailure.emptyInput }
        let seeds = URL.endpointDiscoverySeeds(from: trimmed)
        guard !seeds.isEmpty else { throw DiscoveryFailure.noSeeds }
        var lastError: Error?
        for seed in seeds {
            do {
                let result = try await Web.explore(url: seed)
                if let backend = Backend(rawValue: result.backend.rawValue) {
                    return (result.baseURL, backend)
                }
            } catch {
                lastError = error
            }
        }
        if let lastError {
            throw DiscoveryFailure.underlying(lastError)
        }
        throw DiscoveryFailure.unsupportedBackend
    }
}
