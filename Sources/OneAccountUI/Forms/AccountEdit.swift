import SwiftUI
import ButtonKit
import OneAccount

public struct AccountEdit: View {
    @Environment(\.dismiss) private var dismiss
    let account: AccountRecord
    let onSave: (String) async throws -> Void
    @State private var name: String
    
    public init(account: AccountRecord, onSave: @escaping (String) async throws -> Void) {
        self.account = account
        self.onSave = onSave
        _name = State(initialValue: account.name ?? "")
    }
    
    public var body: some View {
        Form {
            Section {
                TextField(L10n.string("field-name"), text: $name, prompt: Text(account.defaultName))
            
                AsyncButton(action: save) {
                    Label(L10n.string("save"), systemImage: "square.and.arrow.down")
                        .labelStyle(.titleOnly)
                }
                .disabled(name == account.name || (name.isEmpty && account.name == nil) )
            }
        }
        .navigationTitle(L10n.string("rename"))
    }
    
    @MainActor
    func save() async throws {
        try await onSave(name)
        dismiss()
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
