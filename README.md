# OneAccount

Swift package for VMS / cloud authentication: sign-in, account storage, token refresh, and SwiftUI building blocks for the add-account wizard.

## Products and platforms

`Package.swift` declares two library products:

| Product | Role |
|--------|------|
| **OneAccount** | Models, persistence, HTTP session, refresh, endpoint discovery, headless auth |
| **OneAccountUI** | SwiftUI: lists, sheets, fields, account-creation wizards (depends on OneAccount) |

Minimum OS versions: iOS 15, tvOS 18, macOS 13, watchOS 9, visionOS 1; Swift tools 6.1.

## Architecture (core)

**OneAccount** is organized around a few roles:

1. **`AccountStore`** (actor) — in-memory cache and CRUD for `AccountRecord`; optional **`AccountPersistence`** (e.g. Keychain via `AccountStorage.keychain(...).makePersistence()`).
2. **`CurrentAccount`** (`@MainActor`, `ObservableObject`) — single source of truth for the **selected** account: `selectedId`, `runtime`, and a **re-login** signal when refresh fails (`reloginPromptAccountID`).
3. **`AccountRuntime`** (actor) — lifetime of one selected account: `HTTPClient`, optional **`Auth`**, **`PathStatistics`**. Built by **`AccountRuntimeBuilding`**; default is **`DefaultAccountRuntimeFactory`** (Cloud/Next → Bearer + `AuthInterceptor`; intl / nextLegacy → Basic).
4. **`Auth`** (actor) — holds `BackendSession`, applies proactive refresh via **`RefreshPolicy`**; actual refresh is delegated to **`SessionRefresher`** (`CloudSessionRefresher` / `NextSessionRefresher`, etc.).
5. **`AuthService`** — stateless sign-in by URL + backend (Cloud OTP/TOTP, Next gRPC, basic for legacy), plus **`verifyOtp`** for cloud after `SignInOutcome.needsOtp`.
6. **Account creation** — **`AccountCreationFlow`** + **`AccountCreationUseCases`**: endpoint discovery via injected **`DiscoveryClient`** (host app wires **OneDiscovery**), TLS chain preview, draft → **`AccountRecord.init?(draft:)`**.


For SwiftUI account lists, wire **`AccountManager`** as an `environmentObject` — it only loads/refreshes the list from `AccountStore` and does **not** own selection (selection is only on `CurrentAccount`).

## Architecture (UI)

**OneAccountUI** ships ready-made SwiftUI views, field styles, and localized strings (`Localizable.xcstrings`, `bundle: .module`).

**Add-account wizard**

- **`AddAccountWizard`** — shell: owns **`AccountCreationFlow`**, toolbar progress, save + dismiss. Pass **`discovery: DiscoveryClient?`** (required for `.free`, omit for `.locked`). Convenience initializer wires **`AccountCreationWizard`**.
- **`AccountCreationWizard`** — default `Form` body with endpoint discovery, TLS preview, credentials, OTP, and name step.
- **`AccountCreationStepContent`** — step switcher for a custom wizard shell.

**Profile / account management** (`Sources/OneAccountUI/Profile/`)

Composable pieces for a signed-in profile screen. Dependencies are passed explicitly in `init` (no hidden `@EnvironmentObject` inside these views). Section layout stays in the host `Form`.

| View | Role |
|------|------|
| **`AccountProfileHeader`** | Hero block: `@ViewBuilder` avatar, user, endpoint, optional **`SwitchAccountButton`**. Convenience init uses **`DefaultAccountAvatar`** (SF Symbol). Apply **`.accountProfileHeaderListRowStyle()`** inside a `Section`. |
| **`ManageAccountsSection`** | `Section` + localized header + **`ManageAccountsLink`** → **`AccountList`**. |
| **`ManageAccountsLink`** | Navigation link to account list (with edit mode on iOS / visionOS). |
| **`SwitchAccountButton`**, **`AddAccountButton`** | Callback-only buttons (`onSwitchAccount`, `onAddAccount`). |
| **`AccountRenameLink`** | Toolbar / navigation link to **`AccountEdit`**; reads live name from **`AccountManager`** by `accountID`. |
| **`SignOutButton`** | Deletes account and selects the next one (`AsyncButton`). |

**Lists and forms**

- **`AccountList`**, **`AccountSelector`**, **`AccountEdit`**, **`ReloginForm`**, **`AccountLabel`**.

**Fields and discovery**

- Fields: **`URLField`**, **`UsernameField`**, **`PasswordField`**, **`CredentialsField`**, **`OTPField`** / **`OtpField`**.
- **`EndpointLookup`**, **`EndpointSuggestions`**, **`WizardEndpointDiscovery`**.
- Style modifiers: **`.urlField()`**, **`.usernameField()`**, **`.passwordField()`**, **`.credentialsTextField()`**.
- **`View.accountRuntime(_:)`** — inject active **`AccountRuntime`** from the composition root.

## Public API (main types and methods)

Below is the surface meant for use outside the module. Additional DTOs (Cloud/Next errors, response bodies) are also `public`; the list below is enough for typical integration.

### Model

- **`AccountID`** — `UUID`.
- **`AccountRecord`** — `id`, `profile`, `endpoint`, `credentials`, `auth`; convenience initializers and **`init?(draft: AccountCreationDraft)`** to persist after the wizard.
- **`Endpoint`**, **`Credentials`**, **`Profile`**, **`Backend`**, **`AuthMethod`**, **`BackendSession`**, **`DiscoveryCandidate`**.


### Selection and runtime

**`CurrentAccount`**

- `init(store:factory:)` — `nil` factory uses `DefaultAccountRuntimeFactory`.
- `selectAccount(id:)` — `nil` clears selection; creates/tears down `AccountRuntime`.
- `selectedAccountIDBinding` — SwiftUI `Binding<AccountID?>`; `set` schedules `selectAccount(id:)` on the main actor.
- `clearReloginPrompt()`
- `statistics() async` — snapshot from the current runtime.
- Published: `runtime`, `selectedId`, `reloginPromptAccountID`; config: `serverTrustPolicy`, `logger`.

**`AccountRuntime`**

- `account`, `auth`, `http`, `statistics`; `init(account:auth:http:statistics:)`.
- `shutdown()` — internal path when switching accounts (invoked by the coordinator).

**`AccountRuntimeBuilding`** / **`DefaultAccountRuntimeFactory`**

- `build(account:onAuthRefreshFailed:) async -> AccountRuntime?`

**`AccountSource`** — `get(by:)` only; conformed by `AccountStore` via extension.

### Tokens and HTTP

**`Auth`**

- `init(policy:refresher:onPersist:)`
- `setSession(_:)`
- `validAccessToken(refreshIfNeeded:)` → `String`
- `refresh()` → access token after refresh
- `reset()`

**`RefreshPolicy`** — `refreshMargin` for proactive refresh before JWT expiry.

**`SessionRefresher`** — `refresh(_ current: BackendSession?) async throws -> BackendSession`.

**`BackendAuthenticator`** — marker protocol for refresh, compatible with `SessionRefresher`.

**`AuthInterceptor`** — `RequestInterceptor`: Bearer header, 401 retry with refresh; `init(bearerTokenProvider:onRefreshFailed:)` or `convenience init(auth:onRefreshFailed:)`.

**`BearerTokenProvider`** / **`AuthBearerTokenProvider`** — bridge from `Auth` into the interceptor.

### Headless auth

**`AuthService`**

- `init(clientId:backendResolver:)` — `backendResolver` is required for **`signIn(url:user:password:)`** (unknown backend up front).
- `signIn(url:backend:user:password:) async throws -> SignInOutcome`
- `verifyOtp(url:user:code:mode:) async throws -> BackendSession`

**`SignInOutcome`**, **`OtpMode`**, **`AuthServiceError`** (including `isCloudConcurrentSessionLimitExceeded`).

### Account creation (logic)

**`AccountCreationUseCases`**

- `loadCertificates(for:serverTrustPolicy:current:)` → `CertificatePreview`
- `validateCredentials(_:)` → `AccountSignInOutcome`
- `verifyOtp(_:)` → `BackendSession`

**`DiscoveryClient`**, **`DiscoveryPolicy`**, **`DiscoveredEndpoint`** — host-provided discovery (`exploreDiscoveries` / `exploreExact`). V6 uses **`DiscoveryClient.oneDiscovery(policy:)`** over OneDiscovery.

**`AccountCreationFlow`** (`ObservableObject`, `@MainActor`)

- `init(mode:useCases:)` — `EndpointWizardMode.free` or `.locked(ResolvedEndpoint)`.
- Published: `draft`, `step`, `endpointState`, `credentialsState`, `otpState`, `certificatePreview`, `isEndpointLocked`, `canSave`, `wizardTotalSteps`, `wizardCurrentStepIndex`, `shouldPreviewCertificates`.
- `selectDiscoveryRow`, `reloadCertificates`, `continueAfterCertificates`, `signIn`, `verifyOtp`, `resetCredentialState`.

**`Draft`**, **`AccountCreationStep`**, **`EndpointWizardMode`**, step state types in **`AccountCreationState.swift`**.

**`WizardEndpointDiscovery.resolveEndpoint(trimmedURL:discovery:session:)`** — parallel seed resolution using a **`DiscoveryClient`**.

**`HTTPSCertificateProbe.fetchCertificateChain(url:serverTrustPolicy:)`** and **`HTTPSCertificateProbeError`**.

### SwiftUI (OneAccountUI)

**Core**

- **`AccountManager`** — `init(store:onAccountDeleted:)`, `refresh()`, `delete(_:)`, `rename(_:newName:)`.
- **`AccountList`**, **`AccountSelector`**, **`AddAccountWizard`**, **`AccountCreationWizard`**, **`ReloginForm`**, **`AccountEdit`**.

**Profile** (see table above)

- **`AccountProfileHeader`**, **`ManageAccountsSection`**, **`ManageAccountsLink`**, **`SwitchAccountButton`**, **`AddAccountButton`**, **`AccountRenameLink`**, **`SignOutButton`**, **`DefaultAccountAvatar`**.

**Fields and discovery**

- **`URLField`**, **`UsernameField`**, **`PasswordField`**, **`CredentialsField`**, **`OTPField`** / **`OtpField`**.
- **`AccountLabel`**, **`EndpointLookup`**, **`EndpointSuggestions`**, **`WizardEndpointDiscovery`**.

Strings for profile and wizard UI live in **`Localizable.xcstrings`**; host apps do not need their own copies for these components.

## Adding the dependency

In your app or package `Package.swift`:

```swift
.package(url: "https://github.com/avgx/OneAccount.git", branch: "main"),
```

Target:

```swift
.target(name: "MyApp", dependencies: [
    .product(name: "OneAccount", package: "OneAccount"),
    .product(name: "OneAccountUI", package: "OneAccount"), // optional
])
```

## Typical usage

### 1. Store and account selection

```swift
let store = AccountStorage.keychain(keyPrefix: "MyApp", service: "MyApp.accounts").makeStore()
try await store.load()

let accountManager = AccountManager(store: store)
let currentAccount = CurrentAccount(store: store)

// SwiftUI
.environmentObject(accountManager)
.environmentObject(currentAccount)

Task {
    try await accountManager.refresh()
    await currentAccount.selectAccount(id: someId)
}
```

Use `currentAccount.runtime?.http` for requests on behalf of the current account, and `await runtime?.auth?.validAccessToken()` when you need a bearer token outside the interceptor.

### 2. Add account (sheet)

```swift
NavigationStack {
    AddAccountWizard(
        discovery: .oneDiscovery(policy: product.discoveryPolicy),
        serverTrustPolicy: .system,
        clientId: "<oauth-client-id>",
        suggestions: EndpointSuggestions(proposedURLs: [], credentialSeedURLs: [])
    ) { draft in
        guard let record = AccountRecord(draft: draft) else { return }
        Task {
            try await store.save(record)
            try await accountManager.refresh()
        }
    }
}
```

Custom wizard shell:

```swift
AddAccountWizard(
    discovery: myDiscoveryClient,
    clientId: "my-client",
    onSave: { draft in /* persist */ }
) { flow in
    AccountCreationWizard(flow: flow, discovery: myDiscoveryClient, suggestions: .init())
}
```

### 3. Profile screen (signed in)

Host app owns `Form` sections and routing (sheets, menus). Example:

```swift
let showsMulti = accountManager.accounts.count > 1

Form {
    Section {
        AccountProfileHeader(
            account: account,
            showsSwitchAccount: showsMulti,
            onSwitchAccount: { presentAccountPicker() },
            avatar: { record in
                MyAvatarView(record) // optional; omit avatar param for DefaultAccountAvatar
            }
        )
        .accountProfileHeaderListRowStyle()
    }

    if showsMulti {
        ManageAccountsSection(
            accountManager: accountManager,
            currentAccount: currentAccount
        )
    }

    SignOutButton(
        accountManager: accountManager,
        currentAccount: currentAccount,
        accountID: account.id
    )
}
.toolbar {
    ToolbarItem(placement: .principal) {
        AccountRenameLink(
            accountManager: accountManager,
            accountID: account.id,
            onSave: { try await accountManager.rename(account.id, newName: $0) }
        )
    }
}
```

Use **`currentAccount.selectedAccountIDBinding`** with **`AccountList`** / **`AccountSelector`** instead of hand-rolled selection bindings.

### 4. Headless sign-in (no UI)

```swift
let auth = AuthService(clientId: "my-client") { _ in .cloud }
// Resolver is unused when you always call `signIn(url:backend:user:password:)`.
let outcome = try await auth.signIn(url: baseURL, backend: .cloud, user: "u", password: "p")
let code = "" // from your OTP UI
switch outcome {
case .authenticated(let session):
    // Signed in; persist `session` if needed.
    _ = session
case .needsOtp(let modes):
    // Present OTP UI; `modes` lists allowed second factors.
    let session = try await auth.verifyOtp(url: baseURL, user: "u", code: code, mode: .otp)
    _ = (modes, session)
}
```

For a fully custom add-account UI, create **`AccountCreationFlow`** yourself with **`AccountCreationUseCases`** and embed **`AccountCreationStepContent`** or individual step views.
