import SwiftUI
import OneAccount

@MainActor
struct DoneStep: View {

    @Binding var draft: Draft
    let canSave: Bool
    let isSaving: Bool
    var onSave: () async throws -> Void

    var body: some View {
        Section {
            if let endpoint = draft.resolvedEndpoint {
                let defaultName = endpoint.backend == .cloud ? draft.user : "\(draft.user)@\(endpoint.url.pretty())"
                TextField("\(defaultName)", text: $draft.displayName)
            } else {
                TextField("optional", text: $draft.displayName)
            }
        } header: {
            Text("Name")
        }

        ActionButton(
            title: "Add account",
            isLoading: isSaving,
            isDisabled: !canSave || isSaving
        ) {
            try await onSave()
        }
        .disabled(!canSave || isSaving)
    }
}
