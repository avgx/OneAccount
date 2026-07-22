import SwiftUI
import OneAccount
import URLKit

@MainActor
public struct AccountProfileHeader<Avatar: View>: View {
    private let account: AccountRecord
    private let showsSwitchAccount: Bool
    private let vmsVersion: String?
    private let onSwitchAccount: () -> Void
    @ViewBuilder private let avatar: (AccountRecord) -> Avatar

    public init(
        account: AccountRecord,
        showsSwitchAccount: Bool,
        vmsVersion: String? = nil,
        onSwitchAccount: @escaping () -> Void,
        @ViewBuilder avatar: @escaping (AccountRecord) -> Avatar
    ) {
        self.account = account
        self.showsSwitchAccount = showsSwitchAccount
        self.vmsVersion = vmsVersion
        self.onSwitchAccount = onSwitchAccount
        self.avatar = avatar
    }

    public var body: some View {
        VStack(alignment: .center) {
            avatar(account)

            Text(account.user)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.3)

            Text(account.endpoint.url.pretty())
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.3)

            if let vmsVersion, !vmsVersion.isEmpty {
                Text(vmsVersion)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
            }

            if showsSwitchAccount {
                SwitchAccountButton(onSwitchAccount: onSwitchAccount)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

extension AccountProfileHeader where Avatar == DefaultAccountAvatar {
    public init(
        account: AccountRecord,
        showsSwitchAccount: Bool,
        vmsVersion: String? = nil,
        onSwitchAccount: @escaping () -> Void
    ) {
        self.init(
            account: account,
            showsSwitchAccount: showsSwitchAccount,
            vmsVersion: vmsVersion,
            onSwitchAccount: onSwitchAccount,
            avatar: { DefaultAccountAvatar(account: $0) }
        )
    }
}

public struct DefaultAccountAvatar: View {
    let account: AccountRecord

    public init(account: AccountRecord) {
        self.account = account
    }

    public var body: some View {
        Image(systemName: account.icon)
            .font(.largeTitle)
            .frame(width: 80, height: 80)
            .background(Circle().fill(.quaternary))
    }
}
