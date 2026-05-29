import SwiftUI
import OneAccount

@MainActor
struct DoneStep: View {

    @Binding var draft: Draft

    var body: some View {
//        if let endpoint = draft.resolvedEndpoint, endpoint.backend != nil {
//            Section {
//                FormLabeledValue("URL") {
//                    Text(endpoint.url.absoluteString)
//#if !os(tvOS)
//                        .textSelection(.enabled)
//#endif
//                }
//                if let backend = endpoint.backend {
//                    FormLabeledValue("Backend") {
//                        Text(backend.rawValue)
//                    }
//                }
//                FormLabeledValue("User") {
//                    Text(draft.user)
//                }
//            } header: {
//                Text("instance.connect")
//            }
//        }

        Section {
            if let endpoint = draft.resolvedEndpoint, endpoint.backend != nil {
                let defaultName = endpoint.backend == .cloud ? draft.user : "\(draft.user)@\(endpoint.url.pretty())"
                TextField("\(defaultName)", text: $draft.displayName)
            } else {
                TextField("optional", text: $draft.displayName)
            }
        } header: {
            Text("Name")
        }

//        Section {
//            Text("Review and tap the checkmark in the toolbar to save.")
//                .font(.footnote)
//                .foregroundStyle(.secondary)
//        }
    }
}
