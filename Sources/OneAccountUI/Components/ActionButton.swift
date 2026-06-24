import SwiftUI
import ButtonKit

struct ActionButton: View {
    let title: LocalizedStringKey
    let isDisabled: Bool
    let action: () async throws -> Void

    var body: some View {
        Section {
            AsyncButton(action: action) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .background(backgroundColor)
                    .compositingGroup()
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)
            .allowsHitTestingWhenLoading(false)
            .throwableButtonStyle(.shake)
            .asyncButtonStyle(.overlay)
        }
        .listModifiers(isDisabled: isDisabled)
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
