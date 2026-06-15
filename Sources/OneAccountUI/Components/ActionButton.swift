import SwiftUI
import ButtonKit

struct ActionButton: View {
    let title: LocalizedStringKey
    let isLoading: Bool
    let isDisabled: Bool
    let action: () async throws -> Void
    
    var body: some View {
        Section {
            AsyncButton(action: action) {
                HStack {
                    Spacer()
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                .background(backgroundColor)
                .compositingGroup()
            }
            .disabled(isDisabled || isLoading)
            .buttonStyle(.plain)
            .allowsHitTestingWhenLoading(false)
        }
        .listRowBackground(isDisabled ? Color.gray : Color.accentColor)
        #if !os(tvOS)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowSeparator(.hidden)
        #endif
    }
    
    private var backgroundColor: Color {
        switch (isLoading, isDisabled) {
        case (true, _):
            return Color.accentColor.opacity(0.7)
        case (_, true):
            return Color.gray
        default:
            return Color.accentColor
        }
    }
}
