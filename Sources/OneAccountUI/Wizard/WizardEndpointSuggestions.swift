import Foundation
import URLKit

/// Host-provided URL lists for the add-account wizard endpoint step.
public struct WizardEndpointSuggestions: Equatable, Sendable {
    /// Marketing / landing URLs (no embedded credentials).
    public var proposedURLs: [URL]
    /// Preset URLs that may include `user:password@` and `#fragment` labels.
    public var credentialSeedURLs: [URL]

    public init(proposedURLs: [URL] = [], credentialSeedURLs: [URL] = []) {
        self.proposedURLs = proposedURLs
        self.credentialSeedURLs = credentialSeedURLs
    }

    /// Splits the previous built-in demo list into proposed vs credential-bearing seeds.
    public static var defaultForSample: WizardEndpointSuggestions {
        WizardEndpointSuggestions(
            proposedURLs: [
                URL(string: "https://axxonnet.com/")!,
                URL(string: "https://beta.axxonnet.com")!,
            ],
            credentialSeedURLs: [
                URL(string: "http://root:Root1234@try.axxonsoft.com/")!,
            ]
        )
    }

    /// URLs whose match string contains `query` (case-insensitive). Empty `query` returns all.
    public static func filter(_ urls: [URL], matching query: String) -> [URL] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return urls }
        let needle = q.lowercased()
        return urls.filter { matchString(for: $0).contains(needle) }
    }

    /// Host, path, query, and fragment without userinfo — stable for search while typing.
    public static func matchString(for url: URL) -> String {
        guard var c = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.removingCredentials().absoluteString.lowercased()
        }
        c.user = nil
        c.password = nil
        let base = (c.string ?? c.url?.absoluteString ?? url.absoluteString).lowercased()
        return base
    }
}
