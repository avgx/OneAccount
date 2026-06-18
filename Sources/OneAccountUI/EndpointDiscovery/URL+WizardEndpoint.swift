import Foundation

extension URL {
    private static let explicitSchemePrefixes = ["https://", "http://"]

    /// Seeds for discovery: if the user omitted the scheme, try **https** and **http** (in that order).
    public static func endpointDiscoverySeeds(from raw: String) -> [URL] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let lower = trimmed.lowercased()
        if lower.hasPrefix("https://") || lower.hasPrefix("http://") {
            return [URL(string: trimmed)].compactMap { $0 }
        }

        if trimmed.hasPrefix("//") {
            return deduplicated(["https:", "http:"].compactMap { URL(string: $0 + trimmed) })
        }

        return deduplicated(explicitSchemePrefixes.compactMap { URL(string: $0 + trimmed) })
    }

    private static func deduplicated(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        return urls.filter { seen.insert($0.absoluteString).inserted }
    }
}
