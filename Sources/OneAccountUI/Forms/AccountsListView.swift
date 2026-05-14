import SwiftUI
import OneAccount
import SSLPinning

public struct AccountsListView: View {
    @EnvironmentObject private var accountsViewModel: AccountsViewModel
    @EnvironmentObject private var currentAccount: CurrentAccount
    @State private var errorMessage: String?
    @State private var showAddAccount = false
    @State private var reloginAccount: AccountRecord?

    

    @MainActor var onAddAccount: () -> Void
    
    public init(
        onAddAccount: @escaping () -> Void,        
    ) {
        self.onAddAccount = onAddAccount
    }

    public var body: some View {
        List {
            ForEach(accountsViewModel.accounts) { account in
                Button {
                    Task { @MainActor in
                        await currentAccount.selectAccount(id: account.id)
                    }
                } label: {
                    AccountDetailedLabel(
                        account: account,
                        checkmark: account.id == currentAccount.selectedId
                    )
                }
                .buttonStyle(.plain)
            }
            
            Button {
                onAddAccount()
            } label: {
                Label("Add account", systemImage: "person.badge.plus")
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .navigationTitle("Accounts")
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
            try await accountsViewModel.refresh()
        } catch {
            errorMessage = "Failed to load: \(error.localizedDescription)"
        }
    }

}
