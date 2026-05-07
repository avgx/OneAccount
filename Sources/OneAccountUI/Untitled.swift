import SwiftUI
import OneAccount

//@main
//struct MyApp: App {
//    // Каждый аккаунт хранится отдельно по ключу "Account.{UUID}"
//    private let persistence = UserDefaultsPersistence(
//        userDefaults: .standard,
//        keyPrefix: "MyApp.Account"  // Префикс для изоляции от других приложений
//    )
//    
//    private let accountStore = AccountStore(persistence: persistence)
//    
//    var body: some Scene {
//        WindowGroup {
//            AccountsListView(store: accountStore)
//                .task {
//                    try? await accountStore.load()
//                }
//        }
//    }
//}

struct AccountsListView: View {
    let store: AccountStore
    @State private var accounts: [AccountRecord] = []
    @State private var errorMessage: String?
    
    var body: some View {
        List(accounts) { account in
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
            accounts = try await store.getAll()
        } catch {
            errorMessage = "Failed to load: \(error.localizedDescription)"
        }
    }
}
//
//// 1. Атомарные обновления - не нужно перезаписывать весь массив
//try await store.save(account1)  // Только ключ "Account.id1"
//try await store.save(account2)  // Только ключ "Account.id2"
//
//// 2. Легко удалить один аккаунт
//try await store.delete(accountId)  // Удаляется только одна запись
//
//// 3. Можно обновить только specific поля
//try await store.updateSession(accountID: id, session: newSession)
//
//// 4. Простая миграция - можно читать старый формат и конвертировать
//if let oldFormatData = UserDefaults.standard.data(forKey: "oldAccountsKey") {
//    // Мигрируем каждый аккаунт отдельно
//    let oldAccounts = try decoder.decode([OldAccount].self, from: oldFormatData)
//    for old in oldAccounts {
//        let new = convertToNew(old)
//        try await store.save(new)
//    }
//    // Удаляем старый ключ
//    UserDefaults.standard.removeObject(forKey: "oldAccountsKey")
//}

