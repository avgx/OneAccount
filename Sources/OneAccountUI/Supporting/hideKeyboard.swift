import SwiftUI

#if canImport(UIKit)
import UIKit
extension View {
    @MainActor public func hideKeyboard() {
        let resign = #selector(UIResponder.resignFirstResponder)
        UIApplication.shared.sendAction(resign, to: nil, from: nil, for: nil)
    }
}
#elseif canImport(AppKit)
import AppKit
extension View {
    @MainActor public func hideKeyboard() {
        NSApp.keyWindow?.makeFirstResponder(nil)
    }
}
#endif
