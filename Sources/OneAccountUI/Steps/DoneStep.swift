import SwiftUI
import OneAccount

@MainActor
struct DoneStep: View {

    @Binding var draft: Draft

    var body: some View {
        Section {
            if let endpoint = draft.resolvedEndpoint, endpoint.backend != nil {
                let defaultName = endpoint.backend == .cloud ? draft.user : "\(draft.user)@\(endpoint.url.pretty())"
                TextField("\(defaultName)", text: $draft.displayName)
            } else {
                TextField("optional", text: $draft.displayName)
            }
        } header: {
            Text("Name")
        } footer: {
            Text("Review and tap the checkmark in the toolbar to save.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
