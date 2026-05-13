import Foundation

extension URL {
    /// Seeds for discovery: if the user omitted the scheme, try **https** first, then **http**.
    public static func endpointDiscoverySeeds(from raw: String) -> [URL] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return [URL(string: trimmed)].compactMap { $0 }
        }
        return ["https://", "http://"].compactMap { URL(string: $0 + trimmed) }
    }
}
