# OneAccount

Swift package for VMS / cloud authentication: sign-in, account storage, token refresh, and SwiftUI building blocks for the add-account wizard.

## Products and platforms

`Package.swift` declares two library products:

| Product | Role |
|--------|------|
| **OneAccount** | Models, persistence, HTTP session, refresh, endpoint discovery, headless auth |
| **OneAccountUI** | SwiftUI: lists, sheets, fields, account-creation wizards (depends on OneAccount) |

Minimum OS versions: iOS 15, tvOS 15, macOS 13, watchOS 9, visionOS 1; Swift tools 6.1.

## Architecture (core)

**OneAccount** is organized around a few roles:

1. **`AccountStore`** (actor) — in-memory cache and CRUD for `AccountRecord`; optional **`AccountPersistence`** (e.g. Keychain via `AccountStorage.keychain(...).makePersistence()`).
2. **`CurrentAccount`** (`@MainActor`, `ObservableObject`) — single source of truth for the **selected** account: `selectedId`, `runtime`, and a **re-login** signal when refresh fails (`reloginPromptAccountID`).
3. **`AccountRuntime`** (actor) — lifetime of one selected account: `HTTPClient`, optional **`Auth`**, **`PathStatistics`**. Built by **`AccountRuntimeBuilding`**; default is **`DefaultAccountRuntimeFactory`** (Cloud/Next → Bearer + `AuthInterceptor`; intl / nextLegacy → Basic).
4. **`Auth`** (actor) — holds `BackendSession`, applies proactive refresh via **`RefreshPolicy`**; actual refresh is delegated to **`SessionRefresher`** (`CloudSessionRefresher` / `NextSessionRefresher`, etc.).
5. **`AuthService`** — stateless sign-in by URL + backend (Cloud OTP/TOTP, Next gRPC, basic for legacy), plus **`verifyOtp`** for cloud after `SignInOutcome.needsOtp`.
6. **Account creation** — **`AccountCreationFlow`** + **`AccountCreationUseCases`**: resolve URL with **`WizardEndpointDiscovery`** (OneDiscovery), TLS chain preview with **`HTTPSCertificateProbe`**, draft **`AccountCreationDraft`** → **`AccountRecord.init?(draft:)`**.


For SwiftUI account lists, wire **`AccountManager`** as an `environmentObject` — it only loads/refreshes the list from `AccountStore` and does **not** own selection (selection is only on `CurrentAccount`).

## Architecture (UI)

**OneAccountUI** ships ready-made views and styles; the add-account wizard is split by platform and API generation:

- **`AccountCreationWizardLegacy`** — broad compatibility (including iOS/tvOS before 18).
- **`AccountCreationWizardIOS18`** — iOS 18+ (`@available(iOS 18.0, *)`).
- **`AccountCreationWizardTVOS18`** — tvOS 18+.

**`AddAccountSheet`** constructs **`AccountCreationFlow`** internally and takes a `@ViewBuilder` for your wizard, or a convenience initializer that defaults to the legacy wizard.

**`AccountCreationStepContent`** — shared step content for custom shells.

The older monolithic `ConnectionWizard*` views were removed in favor of this layout.

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

- `resolveEndpoint(_:)` → `ResolvedEndpoint`
- `loadCertificates(for:)` → `CertificatePreviewState`
- `validateCredentials(_:)` → `AccountSignInOutcome`
- `verifyOtp(_:)` → `BackendSession`

**`AccountCreationFlow`** (`ObservableObject`, `@MainActor`)

- `init(mode:useCases:)` — `EndpointWizardMode.free` or `.locked(Endpoint)`.
- Published: `draft`, `step`, `endpointState`, `credentialsState`, `otpState`, `certificatePreviewState`, `isEndpointLocked`, `canSave`, `wizardTotalSteps`, `wizardCurrentStepIndex`, `shouldPreviewCertificates`.
- `selectDiscoveryCandidate`, `resolveEndpoint`, `reloadCertificates`, `continueAfterCertificates`, `signIn`, `verifyOtp`, `resetCredentialState`.

**`AccountCreationDraft`**, **`AccountCreationStep`**, **`EndpointWizardMode`**, step state types in **`AccountCreationState.swift`** (`EndpointInputState`, `CredentialsState`, etc.).

**`WizardEndpointDiscovery.resolveEndpoint(trimmedURL:)`** — discover canonical base URL and `Backend`.

**`HTTPSCertificateProbe.fetchCertificateChain(url:serverTrustPolicy:)`** and **`HTTPSCertificateProbeError`**.

### SwiftUI (OneAccountUI)

- **`AccountManager`** — `init(store:)`, `refresh()`, `delete(_:)`.
- **`AccountList`**, **`AccountSelector`**, **`AddAccountSheet`**, **`ReloginSheet`**, **`RenameAccountSheet`** (see initializers in source).
- **`AccountCreationWizardLegacy`**, **`AccountCreationWizardIOS18`**, **`AccountCreationWizardTVOS18`**, **`AccountCreationStepContent`**.
- Fields: **`URLField`**, **`UsernameField`**, **`PasswordField`**, **`CredentialsField`**, **`OTPField`** / typealias **`OtpField`**.
- Misc: **`AvatarView`**, **`AccountDetailedLabel`**, **`ActionButton`**, style view modifiers (`urlFieldStyle`, credentials field style).
- **`EndpointLookup`** — debounced endpoint discovery for the URL field; **`WizardEndpointSuggestions`** — preset/demo URL configuration for samples/apps.

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
    AddAccountSheet(
        serverTrustPolicy: .system,
        clientId: "<oauth-client-id>",
        suggestions: .defaultForSample
    ) { draft in
        guard let record = AccountRecord(draft: draft) else { return }
        Task {
            try await store.save(record)
            try await accountManager.refresh()
        }
    }
}
```

On **iOS 18**, pass a custom wizard:

```swift
AddAccountSheet(clientId: "my-client") { draft in /* persist */ } { flow in
    AccountCreationWizardIOS18(flow: flow)
}
```

If `AddAccountSheet`’s default wiring is not enough, create **`AccountCreationFlow`** yourself with custom **`AccountCreationUseCases`** (custom `AuthService`, TLS trust policy) and pass it into your own `View`.

### 3. Headless sign-in (no UI)

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
