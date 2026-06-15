import Foundation
import OneAccount

extension Backend {
    public var icon: String { self == .cloud ? "icloud" : "pc" } //desktopcomputer ?
    public static let defaultIcon: String = "desktopcomputer"
}
