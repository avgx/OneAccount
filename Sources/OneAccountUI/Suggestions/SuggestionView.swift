import SwiftUI
import OneAccount
import OneDiscovery
import Shimmer
import URLKit

@MainActor
struct SuggestionView: View {
    let url: URL
    @MainActor var didSelect: (DiscoveryCandidate) -> Void

    @State private var loaded = false
    @State private var candidate: DiscoveryCandidate?
    @State private var errorMessage: String?

    var body: some View {
        Button {
            if let candidate {
                didSelect(candidate)
            }
        } label: {
            HStack {
                if let candidate {
                    DiscoveryRowLabel(
                        title: candidate.rowTitle,
                        detail: candidate.rowDetail,
                        isError: false,
                        showsCloudIcon: candidate.endpoint.backend == .cloud
                    )
                } else if let errorMessage {
                    DiscoveryRowLabel(
                        title: url.removingCredentials().pretty(),
                        detail: errorMessage,
                        isError: true
                    )
                } else {
                    DiscoveryRowLabel(
                        title: url.removingCredentials().pretty(),
                        detail: "…",
                        isError: false
                    )
                }
                Spacer()
            }
        }
        .disabled(!loaded || candidate == nil || candidate?.endpoint.backend == nil)
        .redacted(reason: loaded ? [] : .placeholder)
        .shimmering(active: !loaded)
        .task {
            defer { self.loaded = true }
            try? await Task.sleep(nanoseconds: NSEC_PER_SEC)
            await load()
        }
    }

    private func load() async {
        do {
            let result = try await Web.explore(url: url)
            if let backend = OneAccount.Backend(rawValue: result.backend.rawValue) {
                let endpoint = Endpoint(url: result.baseURL, backend: backend)
                self.candidate = DiscoveryCandidate(endpoint: endpoint, summary: result.summary)
                self.errorMessage = nil
            } else {
                self.candidate = nil
                self.errorMessage = "unknown backend"
            }
        } catch {
            self.candidate = nil
            self.errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    VStack(alignment: .leading) {
        SuggestionView(url: URL(string: "https://axxonnet.com/")!) { s in
            print("\(s)")
        }

        SuggestionView(url: URL(string: "http://try.itvgroup.ru:8085/web2/")!) { s in
            print("\(s)")
        }

        SuggestionView(url: URL(string: "https://cloud.itv.ru")!) { s in
            print("\(s)")
        }

        SuggestionView(url: URL(string: "https://1:1@vms.avgx1.keenetic.link/")!) { s in
            print("\(s)")
        }
    }
}
