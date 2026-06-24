import SwiftUI
import OneAccount

@MainActor
struct DoneStep: View {

    @Binding var draft: Draft
    let canSave: Bool
    var onSave: () async throws -> Void

    var body: some View {
        Section {
            if let endpoint = draft.resolvedEndpoint {
                TextField("Name", text: $draft.displayName, prompt: Text(draft.defaultName))
            } else {
                TextField("Name", text: $draft.displayName)
            }
        } header: {
            Text("Name")
        }

        ActionButton(
            title: "Add account",
            isDisabled: !canSave,
            action: onSave
        )
    }
}
