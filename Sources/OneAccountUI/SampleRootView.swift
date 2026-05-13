import SwiftUI
import OneAccount
import RequestResponse
import SSLPinning

@available(iOS 17.0, tvOS 17.0, *)
struct SampleRootView: View {
    let store: AccountStore
    @StateObject private var accountsViewModel: AccountsViewModel
    @StateObject private var currentAccount: CurrentAccount
    @AppStorage("lastAccountID") private var lastAccountIDString: String = ""
    @State private var activeDemo: DemoSheet?
    @State private var testMessage: String?
    @State private var isTesting = false

    private let suggestions: WizardEndpointSuggestions
    private let endpointWizardMode: EndpointWizardMode
    private let serverTrustPolicy: ServerTrustPolicy
    
    @State var showAddAccount = false
    
    init(store: AccountStore = AccountStorage.memory.makeStore()) {
        self.store = store
        _accountsViewModel = StateObject(wrappedValue: AccountsViewModel(store: store))
        _currentAccount = StateObject(wrappedValue: CurrentAccount(store: store))
        
        self.suggestions = .defaultForSample
        self.endpointWizardMode = .free
        self.serverTrustPolicy = .system
    }

    var body: some View {
        NavigationStack {
            AccountsListView(onAddAccount: { showAddAccount.toggle() })
                .environmentObject(accountsViewModel)
                .environmentObject(currentAccount)
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button("тест") {
                            Task { await runCurrentAccountTest() }
                        }
                        .disabled(currentAccount.runtime == nil || isTesting)

                        Menu("Demos") {
                            #if os(iOS)
                            if #available(iOS 18.0, *) {
                                Button("iOS 18 wizard") {
                                    activeDemo = .ios18Wizard
                                }
                            }
                            #endif
                            #if os(tvOS)
                            if #available(tvOS 18.0, *) {
                                Button("tvOS 18 wizard") {
                                    activeDemo = .tvos18Wizard
                                }
                            }
                            #endif
                            Button("Legacy wizard") {
                                activeDemo = .legacyWizard
                            }
                            Button("Account selector") {
                                activeDemo = .accountSelector
                            }
                            Button("Accounts list") {
                                activeDemo = .accountsList
                            }
                        }
                    }
                }
                .task {
                    try? await accountsViewModel.refresh()
                    if let id = AccountID(uuidString: lastAccountIDString) {
                        await currentAccount.selectAccount(id: id)
                    }
                }
                .task {
                    let stream = await currentAccount.accountChanged()
                    for await change in stream where change.phase == .didChange {
                        lastAccountIDString = change.newId?.uuidString ?? ""
                        #if DEBUG
                        print("[SampleRoot] account didChange \(String(describing: change.oldId)) -> \(String(describing: change.newId))")
                        #endif
                    }
                }
        }
        .sheet(isPresented: $showAddAccount) {
            NavigationStack {
                AddAccountSheet(
                    endpointWizardMode: endpointWizardMode,
                    serverTrustPolicy: serverTrustPolicy,
                    clientId: UUID().uuidString,
                    suggestions: suggestions
                ) { draft in
                    saveAccount(draft)
                }
            }
        }
        .sheet(item: $activeDemo) { demo in
            NavigationStack {
                demoContent(for: demo)
                    .environmentObject(accountsViewModel)
                    .environmentObject(currentAccount)
            }
        }
        .alert("Test", isPresented: .constant(testMessage != nil)) {
            Button("OK") { testMessage = nil }
        } message: {
            Text(testMessage ?? "")
        }
    }

    
    private func shouldOfferRelogin(for account: AccountRecord) -> Bool {
        switch account.endpoint.backend {
        case .cloud, .next:
            return true
        case .nextLegacy, .intl, .none:
            return false
        }
    }
    
    @ViewBuilder
    private func demoContent(for demo: DemoSheet) -> some View {
        switch demo {
        case .ios18Wizard:
            #if os(iOS)
            if #available(iOS 18.0, *) {
                AddAccountSheet(
                    clientId: UUID().uuidString,
                    onSave: { saveAccount($0) }
                ) { flow in
                    AccountCreationWizardIOS18(flow: flow)
                }
            } else {
                Text("iOS 18 is required for this wizard.")
            }
            #else
            Text("iOS 18 wizard is only available on iOS.")
            #endif

        case .tvos18Wizard:
            #if os(tvOS)
            if #available(tvOS 18.0, *) {
                AddAccountSheet(
                    clientId: UUID().uuidString,
                    onSave: { saveAccount($0) }
                ) { flow in
                    AccountCreationWizardTVOS18(flow: flow)
                }
            } else {
                Text("tvOS 18 is required for this wizard.")
            }
            #else
            Text("tvOS 18 wizard is only available on tvOS.")
            #endif

        case .legacyWizard:
            AddAccountSheet(clientId: UUID().uuidString) { draft in
                saveAccount(draft)
            }

        case .accountSelector:
            AccountsSelectorSheet(
                accounts: accountsViewModel.accounts,
                currentID: selectedAccountBinding,
                onAddAccount: {
                    activeDemo = .legacyWizard
                }
            )

        case .accountsList:
            AccountsListView(onAddAccount: { showAddAccount.toggle() })
        }
    }

    private var selectedAccountBinding: Binding<AccountID?> {
        Binding(
            get: { currentAccount.selectedId },
            set: { newValue in
                Task { @MainActor in
                    await currentAccount.selectAccount(id: newValue)
                }
            }
        )
    }

    private func saveAccount(_ draft: AccountCreationDraft) {
        guard let record = AccountRecord(draft: draft) else { return }
        Task { @MainActor in
            do {
                try await accountsViewModel.store.save(record)
                try await accountsViewModel.refresh()
            } catch {
                testMessage = error.localizedDescription
            }
        }
    }

    private func runCurrentAccountTest() async {
        guard let runtime = currentAccount.runtime else {
            testMessage = "No current account."
            return
        }
        isTesting = true
        defer { isTesting = false }

        do {
            let account = await runtime.account
            guard let backend = account.endpoint.backend else {
                testMessage = "Current account has no backend."
                return
            }
            let request = backend.testRequest()
            let builder = RequestBuilder.json(baseURL: account.endpoint.url, encoder: JSONEncoder())
            let http = await runtime.http
            _ = try await http.send(request, with: builder)
            testMessage = "OK"
        } catch {
            testMessage = error.localizedDescription
        }
    }
}

private enum DemoSheet: String, Identifiable {
    case ios18Wizard
    case tvos18Wizard
    case legacyWizard
    case accountSelector
    case accountsList

    var id: String { rawValue }
}

#Preview {
    if #available(iOS 17.0, tvOS 17.0,  *) {
        SampleRootView()
    } else {
        // Fallback on earlier versions
        Text("Not available")
    }
}
