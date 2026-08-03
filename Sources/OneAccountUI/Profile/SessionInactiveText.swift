import SwiftUI

@MainActor
public struct SessionInactiveText: View {
    public init() {}

    public var body: some View {
        Text(L10n.string("error.session-inactive"))
    }
}
