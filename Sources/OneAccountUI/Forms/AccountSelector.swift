import SwiftUI
import OneAccount

@MainActor
public struct AccountSelector: View {
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

    private var showsSearch: Bool {
        accounts.count > 5
    }

    private var items: [AccountRecord] {
        let sorted = accounts.sorted { $0.baseURL.absoluteString < $1.baseURL.absoluteString }
        guard showsSearch else { return sorted }
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return sorted }
        let text = searchText.lowercased()
        return sorted.filter {
            $0.baseURL.absoluteString.lowercased().contains(text)
                || $0.user.lowercased().contains(text)
                || ($0.name?.lowercased().contains(text) ?? false)
        }
    }

    @ViewBuilder
    public var content: some View {
        List {
            Section {
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
                        AccountLabel(account)
                            .overlay(alignment: .trailing) {
                                if isCurrent {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                    }
                }
                .buttonStyle(.plain)
                addAccountButton
            }
        }
    }

    public var body: some View {
        if showsSearch {
            content
                .navigationTitle(L10n.string("accounts-title"))
                .searchable(text: $searchText)
        } else {
            content
                .navigationTitle(L10n.string("accounts-title"))
        }
    }

    @ViewBuilder
    private var addAccountButton: some View {
        if let onAddAccount {
            Button {
                dismiss()
                onAddAccount()
            } label: {
                Label(L10n.string("add-account"), systemImage: "person.badge.plus")
            }
        } else {
            EmptyView()
        }
    }
}
