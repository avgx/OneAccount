import SwiftUI

public struct URLFieldModifier: ViewModifier {

    public init() {}

    public func body(content: Content) -> some View {
        #if os(iOS) || os(tvOS) || os(visionOS)
        content
            .keyboardType(.URL)
            .textContentType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        #else
        content
            .autocorrectionDisabled()
        #endif
    }
}

public extension View {

    func urlFieldStyle() -> some View {
        modifier(URLFieldModifier())
    }

    func urlField() -> some View {
        #if os(iOS) || os(tvOS) || os(visionOS)
        self
            .keyboardType(.URL)
            .textContentType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        #else
        self
            .autocorrectionDisabled()
        #endif
    }
}
