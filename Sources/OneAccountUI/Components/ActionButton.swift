import SwiftUI
import ButtonKit

struct ActionButton: View {
    let title: LocalizedStringKey
    let accessibilityLabel: String
    let isDisabled: Bool
    let action: () async throws -> Void

    var body: some View {
        #if os(tvOS)
        Section {
            AsyncButton(action: action) {
                Text(title, bundle: .module)
            }
            .accessibilityLabel(accessibilityLabel)
            .disabled(isDisabled)
            .allowsHitTestingWhenLoading(false)
            .throwableButtonStyle(.shake)
            .asyncButtonStyle(.overlay)
        }
        #else
        Section {
            AsyncButton(action: action) {
                Text(title, bundle: .module)
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .background(backgroundColor)
                    .compositingGroup()
            }
            .accessibilityLabel(accessibilityLabel)
            .buttonStyle(.plain)
            .disabled(isDisabled)
            .allowsHitTestingWhenLoading(false)
            .throwableButtonStyle(.shake)
            .asyncButtonStyle(.overlay)
        }
        .listModifiers(isDisabled: isDisabled)
        #endif
    }

    private var backgroundColor: Color {
        isDisabled ? Color.gray : Color.accentColor
    }
}

extension View {
    func listModifiers(isDisabled: Bool) -> some View {
        #if !os(tvOS)
        self
            .listRowBackground(isDisabled ? Color.gray : Color.accentColor)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowSeparator(.hidden)
        #else
        self
        #endif
    }
}

#if os(iOS) || os(tvOS)
#Preview("Enabled") {
    Form {
        ActionButton(
            title: "sign-in",
            accessibilityLabel: AccessibilityLabels.signIn,
            isDisabled: false,
            action: {}
        )
        
        ActionButton(
            title: "sign-in",
            accessibilityLabel: AccessibilityLabels.signIn,
            isDisabled: false,
            action: {}
        )
    }
}

#Preview("Disabled") {
    Form {
        ActionButton(
            title: "continue",
            accessibilityLabel: AccessibilityLabels.continueButton,
            isDisabled: true,
            action: {}
        )
    }
}
#endif
