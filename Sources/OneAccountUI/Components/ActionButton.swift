import SwiftUI
import ButtonKit

struct ActionButton: View {
    let title: LocalizedStringKey
    let isLoading: Bool
    let action: () async throws -> Void
    
    var body: some View {
        Section {
            AsyncButton(action: action) {
                HStack {
                    Spacer()
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Text(title)
                    }
                    Spacer()
                }
                .compositingGroup()
            }
            .asyncButtonStyle(.overlay)
            .buttonStyle(.borderedProminent)
            .allowsHitTestingWhenLoading(false)
        }
        .listRowBackground(Color.accentColor)
        #if !os(tvOS)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowSeparator(.hidden)
        #endif
    }
}
