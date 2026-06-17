import SwiftUI
import OneAccount

struct AccountEdit: View {
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
        Form {
            Section {
                TextField("Name", text: $name)
            } footer: {
                VStack {
                    LabeledRow("URL", systemImage: "globe", value: account.baseURL.pretty())
                    LabeledRow("User", systemImage: "person", value: account.user)
                }
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Rename")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: { dismiss() }){
                    Image(systemName: "xmark")
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(action: {
                    onSave(name)
                    dismiss()
                }) {
                    Image(systemName: "checkmark")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        
    }
}

#Preview {
    NavigationView {
        AccountEdit(
            account: .init(
                baseURL: URL(string:"https://example.com/")!,
                user: "root",
                password: "root"
            )
        ) { name in
            print("rename to \(name)")
        }
    }
}
