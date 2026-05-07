import SwiftUI
import OneAccount

struct RenameAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    let account: AccountRecord
    let onSave: (String) -> Void
    @State private var name: String
    
    init(account: AccountRecord, onSave: @escaping (String) -> Void) {
        self.account = account
        self.onSave = onSave
        _name = State(initialValue: account.name ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                Text("URL: \(account.baseURL.absoluteString)")
                Text("User: \(account.user)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Rename")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name)
                        dismiss()
                    }
                }
            }
        }
    }
}
