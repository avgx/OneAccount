import SwiftUI

@MainActor
public struct URLField: View {

    @Binding var text: String

    public init(text: Binding<String>) {
        self._text = text
    }

    public var body: some View {
        #if os(iOS) || os(tvOS) || os(visionOS)
        TextField("url", text: $text)
            .keyboardType(.URL)
            .textContentType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .layoutPriority(1000)
            .ignoresSafeArea(.keyboard, edges: .bottom)
        #else
        TextField("url", text: $text)
            .autocorrectionDisabled()
            .layoutPriority(1000)
        #endif
    }
}

#Preview {
    List {
        Section {
            URLField(text: .constant(""))
        }
        Section {
            URLField(text: .constant("example.com"))
        }
    }
}
