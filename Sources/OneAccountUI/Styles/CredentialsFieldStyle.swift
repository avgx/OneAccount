import SwiftUI

public extension View {

    func credentialsTextField() -> some View {
        #if os(iOS) || os(tvOS) || os(visionOS)
        self
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .keyboardType(.default)
        #else
        self
            .autocorrectionDisabled()
        #endif
    }

    func usernameField() -> some View {
        #if os(iOS) || os(tvOS) || os(visionOS)
        self
            .credentialsTextField()
            .textContentType(.username)
            .submitLabel(.next)
        #else
        self
            .credentialsTextField()
        #endif
    }

    func passwordField() -> some View {
        #if os(iOS) || os(tvOS) || os(visionOS)
        self
            .credentialsTextField()
            .textContentType(.password)
            .submitLabel(.done)
        #else
        self
            .credentialsTextField()
        #endif
    }
}
