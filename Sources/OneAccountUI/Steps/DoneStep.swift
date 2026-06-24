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
                TextField(L10n.string("field-name"), text: $draft.displayName, prompt: Text(draft.defaultName))
            } else {
                TextField(L10n.string("field-name"), text: $draft.displayName)
            }
        } header: {
            Text("field-name", bundle: .module)
        }

        ActionButton(
            title: "add-account",
            isDisabled: !canSave,
            action: onSave
        )
    }
}
