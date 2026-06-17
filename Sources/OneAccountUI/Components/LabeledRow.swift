import SwiftUI

/// Settings-style labeled row for `Form` / `List`. Uses `LabeledContent` on iOS 16+ and an
/// `HStack` fallback on iOS 15.
@MainActor
struct LabeledRow<Content: View>: View {
    private let title: LocalizedStringKey
    private let systemImage: String?
    @ViewBuilder private let content: () -> Content

    init(
        _ title: LocalizedStringKey,
        systemImage: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.content = content
    }

    var body: some View {
        if #available(iOS 16.0, tvOS 16.0, macOS 13.0, *) {
            LabeledRowModern(title: title, systemImage: systemImage, content: content)
        } else {
            LabeledRowLegacy(title: title, systemImage: systemImage, content: content)
        }
    }
}

extension LabeledRow where Content == Text {
    init(_ title: LocalizedStringKey, systemImage: String? = nil, value: String) {
        self.init(title, systemImage: systemImage) {
            Text(value)
        }
    }
}

@available(iOS 16.0, tvOS 16.0, macOS 13.0, *)
@MainActor
private struct LabeledRowModern<Content: View>: View {
    let title: LocalizedStringKey
    let systemImage: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        LabeledContent {
            content()
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        } label: {
            rowLabel
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var rowLabel: some View {
        if let systemImage {
            Label(title, systemImage: systemImage)
        } else {
            Text(title)
        }
    }
}

@MainActor
private struct LabeledRowLegacy<Content: View>: View {
    let title: LocalizedStringKey
    let systemImage: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            rowLabel
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            content()
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var rowLabel: some View {
        if let systemImage {
            Label(title, systemImage: systemImage)
        } else {
            Text(title)
        }
    }
}

extension View {
  @ViewBuilder
  func labeledRowHighlighted(_ highlighted: Bool) -> some View {
    if highlighted {
      self.listRowBackground(Color.accentColor.opacity(0.15))
    } else {
      self
    }
  }
}
