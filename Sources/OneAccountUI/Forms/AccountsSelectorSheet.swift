import SwiftUI
import OneAccount

@MainActor
public struct AccountsSelectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText: String = ""
    
    let accounts: [AccountRecord]
    @Binding var currentID: AccountID?
    let onAddAccount: (() -> Void)?
    
    public init(accounts: [AccountRecord], currentID: Binding<AccountID?>, onAddAccount: (() -> Void)? = nil) {
        self.accounts = accounts
        self._currentID = currentID
        self.onAddAccount = onAddAccount
    }
    
    @ViewBuilder
    public var content: some View {
        List {
            Section {
                let items = accounts
                    .sorted { $0.baseURL.absoluteString < $1.baseURL.absoluteString }
                    .filter {
                        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return true }
                        let text = searchText.lowercased()
                        return $0.baseURL.absoluteString.lowercased().contains(text)
                            || $0.user.lowercased().contains(text)
                            || ($0.name?.lowercased().contains(text) ?? false)
                    }
                ForEach(items, id: \.id) { account in
                    Button(action: {
                        var transation = Transaction()
                        transation.disablesAnimations = true
                        withTransaction(transation) {
                            currentID = account.id
                            dismiss()
                        }
                    }) {
                        let isCurrent = account.id == currentID
                        AccountDetailedLabel(account: account, checkmark: isCurrent)
                    }
                }
                .buttonStyle(.plain)
                addAccountButton
            }
        }
    }
    
    public var body: some View {
            content
                .navigationTitle("accounts")
                .searchable(text: $searchText)
    }
    
    private var addAccountButton: some View {
        Button {
            dismiss()
            onAddAccount?()
        } label: {
            Label("Add account", systemImage: "person.badge.plus")
        }
    }
    
}
