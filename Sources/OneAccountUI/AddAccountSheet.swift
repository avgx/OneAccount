import SwiftUI
import OneAccount

struct AddAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var user = ""
    @State private var password = ""
    @State private var baseURL = "https://"
    @State private var backend: Backend = .next
    
    let onSave: (String, String, String, String, Backend) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("User", text: $user)
                TextField("Password", text: $password)
                TextField("Base URL", text: $baseURL)
                Picker("Backend", selection: $backend) {
                    Text("Cloud").tag(Backend.cloud)
                    Text("Next").tag(Backend.next)
                    Text("Next Legacy").tag(Backend.nextLegacy)
                    Text("Intl").tag(Backend.intl)
                }
            }
            .navigationTitle("Add Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name, user, password, baseURL, backend)
                        dismiss()
                    }
                    .disabled(user.isEmpty || baseURL.isEmpty || password.isEmpty)
                }
            }
        }
    }
}
