import SwiftUI

/// iOS 15–compatible row styled like `LabeledContent` inside a `Form`.
@MainActor
struct FormLabeledValue<Content: View>: View {
    private let title: LocalizedStringKey
    @ViewBuilder private let content: () -> Content

    init(_ title: LocalizedStringKey, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            content()
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }
}
