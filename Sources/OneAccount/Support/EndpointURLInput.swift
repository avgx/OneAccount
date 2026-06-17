import Foundation
import URLKit

enum EndpointURLInput {
    /// Returns whether the user's text already identifies the same endpoint URL as discovery resolved.
    static func matchesResolvedURL(_ input: String, resolved: URL) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let resolvedKey = normalizedKey(for: resolved)
        if let parsed = URL(string: trimmed), normalizedKey(for: parsed) == resolvedKey {
            return true
        }
        return false
    }

    private static func normalizedKey(for url: URL) -> String {
        guard var components = URLComponents(url: url.removingCredentials(), resolvingAgainstBaseURL: false) else {
            return url.absoluteString.lowercased()
        }
        components.fragment = nil
        if components.path == "/" {
            components.path = ""
        } else if components.path.hasSuffix("/"), components.path.count > 1 {
            components.path = String(components.path.dropLast())
        }
        return (components.url ?? url).absoluteString.lowercased()
    }
}
