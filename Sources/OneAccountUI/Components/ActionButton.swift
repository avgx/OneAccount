import SwiftUI
import ButtonKit

struct ActionButton: View {
    let title: LocalizedStringKey
    let isLoading: Bool
    let isDisabled: Bool
    let action: () async throws -> Void
    
    var body: some View {
        #if os(tvOS)
        Section {
            AsyncButton(action: action) {
                HStack {
                    Spacer()
                    if isLoading {
                        ProgressView()
                    } else {
                        Text(title)
                    }
                    Spacer()
                }
                .frame(minHeight: 66)
            }
            .buttonStyle(.plain)
            .disabled(isDisabled || isLoading)
            .allowsHitTestingWhenLoading(false)
        }
        #else
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
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowSeparator(.hidden)
        #endif
    }
    
    #if !os(tvOS)
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
    #endif
}
