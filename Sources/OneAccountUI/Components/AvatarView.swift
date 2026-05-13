import SwiftUI

@MainActor
public struct AvatarView: View {
    
    @Environment(\.isFocused) var isFocused: Bool
    
    public let letters: String
    public let url: URL
    
    public var body: some View {
        Circle()
            .fill(backgroundColor.opacity(0.25))
            .overlay( Circle().stroke(.primary.opacity(0.25), lineWidth: 1) )
            .scaleEffect(isFocused ? 1.25 : 1.0)
            .overlay(
                Text(initials)
                    .scaledToFit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
            )        
    }
    
    private var initials: String {
        guard let words = letters
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "\\").last?
            .split(separator: "@").first?
            .replacingOccurrences(of: " ", with: ".")
            .split(separator: ".")
            .prefix(2), !words.isEmpty
        else { return "?" }
        
        return words
            .map { String($0.prefix(1)).uppercased() }
            .joined()
    }
    
    private var backgroundColor: Color {
        let hash = abs(url.absoluteString.hashValue)
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.5, brightness: 0.8)
    }
    
    public init(_ letters: String, url: URL) {
        self.letters = letters
        self.url = url
    }
}

#Preview {
    ScrollView {
        AvatarView("alexey@gmail.com", url: URL(fileURLWithPath: "http://try.example.com:8000/asip-api"))
        AvatarView("alexey.g@example.com", url: URL(fileURLWithPath: "https://beta.example.com"))
        AvatarView("root", url: URL(fileURLWithPath: "https://example.com"))
        AvatarView("\\\\mydomain\\alexey.g.g.g", url: URL(fileURLWithPath: "https://github.com/hashcat-hash-modes.md"))
        AvatarView(".", url: URL(fileURLWithPath: "https://habr.com/ru/articles/709228/"))
        AvatarView("artem.ch", url: URL(fileURLWithPath: "https://www.youtube.com/watch"))
        AvatarView("Server 3", url: URL(fileURLWithPath: "https://www.youtube.com/watch"))
    }
}
