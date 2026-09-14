import SwiftUI
import OneAccount

@MainActor
struct DoneStep: View {

    @Binding var draft: Draft
    let canSave: Bool
    var onSave: () async throws -> Void

    var body: some View {
        Section {
            if draft.resolvedEndpoint != nil {
                TextField(L10n.string("field-name"), text: $draft.displayName, prompt: Text(draft.defaultName))
                    .accessibilityLabel(AccessibilityLabels.name)
            } else {
                TextField(L10n.string("field-name"), text: $draft.displayName)
                    .accessibilityLabel(AccessibilityLabels.name)
            }
        } header: {
            Text("field-name", bundle: .module)
        }

        ActionButton(
            title: "add-account",
            accessibilityLabel: AccessibilityLabels.addAccount,
            isDisabled: !canSave,
            action: onSave
        )
    }
}
