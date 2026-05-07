import SwiftUI
import OneAccount

struct AccountsListView: View {
    @EnvironmentObject private var accountManager: AccountManager
    @State private var errorMessage: String?
    
    var body: some View {
        List(accountManager.accounts) { account in
            VStack(alignment: .leading) {
                Text(account.name ?? "")
                    .font(.headline)
                Text(account.user)
                    .font(.caption)
                Text(account.baseURL.absoluteString)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .refreshable {
            await loadAccounts()
        }
        .task {
            await loadAccounts()
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    private func loadAccounts() async {
        do {
            try await accountManager.refresh()
        } catch {
            errorMessage = "Failed to load: \(error.localizedDescription)"
        }
    }
}
