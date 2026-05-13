import SwiftUI
import OneAccount

@MainActor
struct SuggestionSection: View {
    let title: LocalizedStringKey
    let urls: [URL]
    @MainActor var didSelect: (DiscoveryCandidate) -> Void

    @State var uuid: UUID = UUID()

    init(title: LocalizedStringKey, urls: [URL], didSelect: @escaping (DiscoveryCandidate) -> Void) {
        self.title = title
        self.urls = urls
        self.didSelect = didSelect
    }

    var body: some View {
        content
            .id(uuid)
    }

    @ViewBuilder
    var content: some View {
        Section(content: {
            ForEach(urls, id: \.self) { url in
                SuggestionView(url: url, didSelect: didSelect)
            }
        }, header: {
            HStack {
                Text(title)
                Spacer()
                Button(action: { uuid = UUID() }, label: {
                    Image(systemName: "arrow.counterclockwise")
                        .imageScale(.small)
                })
            }

        })
    }
}

#Preview {
    List {
        SuggestionSection(title: "suggestions", urls: [
            URL(string: "https://axxonnet.com/")!,
            URL(string: "http://try.axxonsoft.com")!
        ], didSelect: { s in
            print("\(s)")
        })
    }
}
